-- Luau bytecode disassembler, written in Luau
-- Created by Epix#3333 (https://github.com/EpixScripts)
-- For details on instructions, see the Luau source: https://github.com/Roblox/luau/blob/master/Compiler/include/Luau/Bytecode.h
-- This puts the `disassemble` function into the global environment, which takes a bytecode string and returns a disassembly string.
-- This is most practical when a `string.dump` or `getscriptbytecode` function exists.
-- A reason to use a disassembler instead of a decompiler is that decompilers are not perfect, and there are anti-decompile methods.

local function dissectImport(id, k)
	-- Import IDs have the top two bits as the length of the chain, and then 3 10-bit fields of constant string indices
	local count = bit32.extract(id, 30, 2)

	local k0 = k[bit32.extract(id, 20, 10) + 1]
	local k1 = count > 1 and k[bit32.extract(id, 10, 10) + 1]
	local k2 = count > 2 and k[bit32.extract(id, 0, 10) + 1]

	local displayString = k0
	if k1 then
		displayString ..= "." .. k1
		if k2 then
			displayString ..= "." .. k2
		end
	end

	return {
		["count"] = count,
		["displayString"] = displayString,
	}
end

local function deserialize(bytecode)
	-- LBC_VERSION_FUTURE includes linedefined for protos
	local LBC_VERSION = 1
	local LBC_VERSION_FUTURE = 2

	-- Current read position in the bytecode string
	local offset = 1

	local function readByte()
		local number = string.unpack("B", bytecode, offset)
		offset += 1
		return number
	end

	local function readLEB128()
		local l_readByte = readByte -- Stored in a local so the upvalue doesn't need to be grabbed multiple times

		local result = 0
		local b = 0 -- amount of bits to shift
		local c;

		repeat
			c = l_readByte()
			local c2 = bit32.band(c, 0x7F)
			result = bit32.bor(result, bit32.lshift(c2, b))
			b += 7
		until not bit32.btest(c, 0x80)

		return result
	end

	local function readUInt32()
		local number = string.unpack("<I", bytecode, offset)
		offset += 4
		return number
	end

	local function readFloat64()
		local number = string.unpack("<d", bytecode, offset)
		offset += 8
		return number
	end

	local function readLengthPrefixedString()
		local length = readLEB128()
		local str = string.unpack("c" .. length, bytecode, offset)
		offset += length
		return str
	end

	local bytecodeVersion = readByte()
	assert(bytecodeVersion ~= 0, "Cannot deserialize bytecode that is a compilation error")
	assert(
		bytecodeVersion == LBC_VERSION or bytecodeVersion == LBC_VERSION_FUTURE,
		"Invalid bytecode version (must be 1 or 2, got " .. bytecodeVersion .. ")"
	)

	local stringCount = readLEB128()
	local stringTable = table.create(stringCount)
	if stringCount > 0 then
		for stringIdx = 1, stringCount do
			stringTable[stringIdx] = readLengthPrefixedString()
		end
	end

	local protoCount = readLEB128()
	local protoTable = table.create(protoCount)
	for protoIdx = 1, protoCount do
		local proto = {}

		proto.maxstacksize = readByte()
		proto.numparams = readByte()
		proto.nups = readByte()
		proto.is_vararg = readByte()

		proto.sizecode = readLEB128()
		proto.code = table.create(proto.sizecode)
		for codeIdx = 1, proto.sizecode do
			proto.code[codeIdx] = readUInt32()
		end

		proto.sizek = readLEB128()
		proto.k = table.create(proto.sizek)
		for kIdx = 1, proto.sizek do
			local kType = readByte()

			if kType == 0 then -- nil
				proto.k[kIdx] = nil
			elseif kType == 1 then -- boolean
				proto.k[kIdx] = readByte() ~= 0
			elseif kType == 2 then -- number
				proto.k[kIdx] = readFloat64()
			elseif kType == 3 then -- string
				proto.k[kIdx] = stringTable[readLEB128()]
			elseif kType == 4 then -- import
				proto.k[kIdx] = dissectImport(readUInt32(), proto.k)
			elseif kType == 5 then -- table
				for _ = 1, readLEB128() do
					readLEB128()
				end
			elseif kType == 6 then -- closure
				proto.k[kIdx] = readLEB128() -- proto id
			else
				error("Unexpected constant type: " .. kType .. " is not a recognized type")
			end
		end

		proto.sizep = readLEB128()
		proto.p = table.create(proto.sizep)
		for innerProtoIdx = 1, proto.sizep do
			proto.p[innerProtoIdx] = readLEB128()
		end

		if bytecodeVersion == LBC_VERSION_FUTURE then
			proto.linedefined = readLEB128()
		end

		local debugNameId = readLEB128()
		if debugNameId ~= 0 then
			proto.debugname = stringTable[debugNameId]
		end

		if readByte() ~= 0 then -- lineinfo?
			proto.linegaplog2 = readByte()

			local intervals = bit32.rshift(proto.sizecode - 1, proto.linegaplog2) + 1

			for _ = 1, proto.sizecode do
				readByte()
			end
			for _ = 1, intervals do
				readByte()
				readByte()
				readByte()
				readByte()
			end
		end

		if readByte() ~= 0 then -- debuginfo?
			proto.sizelocvars = readLEB128()
			for _ = 1, proto.sizelocvars do
				readLEB128()
				readLEB128()
				readLEB128()
				readByte()
			end

			proto.sizeupvalues = readLEB128()
			for _ = 1, proto.sizeupvalues do
				readLEB128()
			end
		end

		protoTable[protoIdx] = proto
	end

	local mainId = readLEB128()

	return protoTable, mainId
end

local function uint16_to_signed(n)
	local sign = bit32.btest(n, 0x8000)
	n = bit32.band(n, 0x7FFF)

	if sign then
		return n - 0x8000
	else
		return n
	end
end
local function uint24_to_signed(n)
	local sign = bit32.btest(n, 0x800000)
	n = bit32.band(n, 0x7FFFFF)

	if sign then
		return n - 0x800000
	else
		return n
	end
end

local function get_opcode(insn)
	return bit32.band(insn, 0xFF)
end
local function get_arga(insn)
	return bit32.band(bit32.rshift(insn, 8), 0xFF)
end
local function get_argb(insn)
	return bit32.band(bit32.rshift(insn, 16), 0xFF)
end
local function get_argc(insn)
	return bit32.rshift(insn, 24)
end
local function get_argd(insn)
	return uint16_to_signed(bit32.rshift(insn, 16))
end
local function get_arge(insn)
	return uint24_to_signed(bit32.rshift(insn, 8))
end

local function getConstantString(constant)
	local constantString;
	if type(constant) == "string" then
		constantString = "'" .. constant .. "'"
	elseif type(constant) == "number" then
		constantString = string.format("%4.3f", constant)
	elseif type(constant) == "boolean" then
		constantString = constant and "true" or "false"
	else
		constantString = "unknown " .. type(constant)
	end
	return constantString
end

getgenv().disassemble = function(bytecodeString)
	assert(type(bytecodeString) == "string", "Argument #1 to `disassemble` must be a string")

	local CAPTURE_TYPES = {
		[0] = "VAL",
		[1] = "REF",
		[2] = "UPVAL",
	}

	--local output = table.create(#bytecodeString * 6)
	local output = {}

	local protoTable = deserialize(bytecodeString)

	for protoId, proto in ipairs(protoTable) do
		table.insert(output, "; global id: " .. (protoId - 1) .. "\n")
		if proto.linedefined then
			table.insert(output, "; line defined: " .. proto.linedefined .. "\n")
		end
		table.insert(output, "; proto name: " .. (proto.debugname or "UNNAMED") .. "\n\n")

		table.insert(output, "; maxstacksize: " .. proto.maxstacksize .. "\n")
		table.insert(output, "; numparams: " .. proto.numparams .. "\n")
		table.insert(output, "; nups: " .. proto.nups .. "\n")
		table.insert(output, "; is_vararg: " .. proto.is_vararg .. "\n\n")

		if #proto.p > 0 then
			table.insert(output, "; child protos: " .. table.concat(proto.p, ", ") .. "\n\n")
		end

		table.insert(output, "; sizecode: " .. proto.sizecode .. "\n")
		table.insert(output, "; sizek: " .. proto.sizek .. "\n\n")

		local pc = 1
		while pc <= proto.sizecode do
			table.insert(output, string.format("[%03i] ", pc - 1))

			local insn = proto.code[pc]
			local opcode = get_opcode(insn)

			if opcode == 0x00 then -- NOOP
				table.insert(output, string.format("NOOP (%#010x)\n", insn))
			elseif opcode == 0xE3 then -- BREAK
				table.insert(output, "BREAK\n")
			elseif opcode == 0xC6 then -- LOADNIL
				table.insert(output, "LOADNIL " .. get_arga(insn) .. "\n")
			elseif opcode == 0xA9 then -- LOADB
				local targetRegister = get_arga(insn)
				local boolValue = get_argb(insn)
				local jumpOffset = get_argc(insn)

				if jumpOffset > 0 then
					table.insert(output, string.format(
						"LOADB %i %i %i ; %s, jump to %i\n",
						targetRegister,
						boolValue,
						jumpOffset,
						boolValue ~= 0 and "true" or "false",
						pc + jumpOffset
					))
				else
					table.insert(output, string.format(
						"LOADB %i %i ; %s\n",
						targetRegister,
						boolValue,
						boolValue ~= 0 and "true" or "false"
					))
				end
			elseif opcode == 0x8C then -- LOADN
				table.insert(output, string.format(
					"LOADN %i %i\n",
					get_arga(insn),
					get_argd(insn)
				))
			elseif opcode == 0x6F then -- LOADK
				local constantIndex = get_argd(insn)
				local constant = proto.k[constantIndex + 1]
				local constantString = getConstantString(constant)

				table.insert(output, string.format(
					"LOADK %i %i ; K(%i) = %s\n",
					get_arga(insn),
					constantIndex,
					constantIndex,
					constantString
				))
			elseif opcode == 0x52 then -- MOVE
				table.insert(output, string.format(
					"MOVE %i %i\n",
					get_arga(insn),
					get_argd(insn)
				))
			elseif opcode == 0x35 then -- GETGLOBAL
				local target = get_arga(insn)
				pc += 1
				local aux = proto.code[pc]
				table.insert(output, string.format(
					"GETGLOBAL %i %i ; K(%i) = '%s'\n",
					target,
					aux,
					aux,
					proto.k[aux + 1]
				))
			elseif opcode == 0x18 then -- SETGLOBAL
				local source = get_arga(insn)
				pc += 1
				local aux = proto.code[pc]
				table.insert(output, string.format(
					"SETGLOBAL %i %i ; K(%i) = '%s'\n",
					source,
					aux,
					aux,
					proto.k[aux + 1]
				))
			elseif opcode == 0xFB then -- GETUPVAL
				table.insert(output, string.format(
					"GETUPVAL %i %i\n",
					get_arga(insn),
					get_argb(insn)
				))
			elseif opcode == 0xDE then -- SETUPVAL
				table.insert(output, string.format(
					"SETUPVAL %i %i\n",
					get_arga(insn),
					get_argb(insn)
				))
			elseif opcode == 0xC1 then -- CLOSEUPVALS
				table.insert(output, "CLOSEUPVALS " .. get_arga(insn) .. "\n")
			elseif opcode == 0xA4 then -- GETIMPORT
				local target = get_arga(insn)
				local importId = get_argd(insn)
				pc += 1 -- skip aux
				local import = proto.k[importId + 1]
				table.insert(output, string.format(
					"GETIMPORT %i %i ; count = %i, '%s'\n",
					target,
					importId,
					import.count,
					import.displayString
				))
			elseif opcode == 0x87 then -- GETTABLE
				table.insert(output, string.format(
					"GETTABLE %i %i %i\n",
					get_arga(insn),
					get_argb(insn),
					get_argc(insn)
				))
			elseif opcode == 0x6A then -- SETTABLE
				table.insert(output, string.format(
					"SETTABLE %i %i %i\n",
					get_arga(insn),
					get_argb(insn),
					get_argc(insn)
				))
			elseif opcode == 0x4D then -- GETTABLEKS
				local targetRegister = get_arga(insn)
				local tableRegister = get_argb(insn)
				pc += 1
				local aux = proto.code[pc]
				table.insert(output, string.format(
					"GETTABLEKS %i %i %i ; K(%i) = '%s'\n",
					targetRegister,
					tableRegister,
					aux,
					aux,
					proto.k[aux + 1]
				))
			elseif opcode == 0x30 then -- SETTABLEKS
				local sourceRegister = get_arga(insn)
				local tableRegister = get_argb(insn)
				pc += 1
				local aux = proto.code[pc]
				table.insert(output, string.format(
					"SETTABLEKS %i %i %i ; K(%i) = '%s'\n",
					sourceRegister,
					tableRegister,
					aux,
					aux,
					proto.k[aux + 1]
				))
			elseif opcode == 0x13 then -- GETTABLEN
				local argc = get_argc(insn)
				table.insert(output, string.format(
					"GETTABLEN %i %i %i ; index = %i\n",
					get_arga(insn),
					get_argb(insn),
					argc,
					argc + 1
				))
			elseif opcode == 0xF6 then -- SETTABLEN
				local argc = get_argc(insn)
				table.insert(output, string.format(
					"SETTABLEN %i %i %i ; index = %i\n",
					get_arga(insn),
					get_argb(insn),
					argc,
					argc + 1
				))
			elseif opcode == 0xD9 then -- NEWCLOSURE
				local childProtoId = get_argd(insn)
				table.insert(output, string.format(
					"NEWCLOSURE %i %i ; global id = %i\n",
					get_arga(insn),
					childProtoId,
					proto.p[childProtoId + 1]
				))
			elseif opcode == 0xBC then -- NAMECALL
				local targetRegister = get_arga(insn)
				local sourceRegister = get_argb(insn)
				pc += 1
				local aux = proto.code[pc]
				table.insert(output, string.format(
					"NAMECALL %i %i %i ; K(%i) = '%s'\n",
					targetRegister,
					sourceRegister,
					aux,
					aux,
					proto.k[aux + 1]
				))
			elseif opcode == 0x9F then -- CALL
				local nargs = get_argb(insn)
				local nresults = get_argc(insn)

				table.insert(output, string.format(
					"CALL %i %i %i ; %s arguments, %s results\n",
					get_arga(insn),
					nargs,
					nresults,
					nargs ~= 0 and tostring(nargs - 1) or "MULTRET",
					nresults ~= 0 and tostring(nresults - 1) or "MULTRET"
				))
			elseif opcode == 0x82 then -- RETURN
				local arga = get_arga(insn)
				local argb = get_argb(insn)
				table.insert(output, string.format(
					"RETURN %i %i ; values start at %i, num returned values = %s\n",
					arga,
					argb,
					arga,
					argb ~= 0 and tostring(argb - 1) or "MULTRET"
				))
			elseif opcode == 0x65 then -- JUMP
				local offset = get_argd(insn)
				table.insert(output, string.format(
					"JUMP %i ; to %i\n",
					offset,
					pc + offset
				))
			elseif opcode == 0x48 then -- JUMPBACK
				local offset = get_argd(insn)
				table.insert(output, string.format(
					"JUMPBACK %i ; to %i\n",
					offset,
					pc + offset
				))
			elseif opcode == 0x2B then -- JUMPIF
				local sourceRegister = get_arga(insn)
				local offset = get_argd(insn)
				table.insert(output, string.format(
					"JUMPIF %i %i ; to %i\n",
					sourceRegister,
					offset,
					pc + offset
				))
			elseif opcode == 0x0E then -- JUMPIFNOT
				local sourceRegister = get_arga(insn)
				local offset = get_argd(insn)
				table.insert(output, string.format(
					"JUMPIFNOT %i %i ; to %i\n",
					sourceRegister,
					offset,
					pc + offset
				))
			elseif opcode == 0xF1 then -- JUMPIFEQ
				local register1 = get_arga(insn)
				local offset = get_argd(insn)
				local jumpTo = pc + offset
				pc += 1
				local aux = proto.code[pc]
				table.insert(output, string.format(
					"JUMPIFEQ %i %i %i ; to %i\n",
					register1,
					aux,
					offset,
					jumpTo
				))
			elseif opcode == 0xD4 then -- JUMPIFLE
				local register1 = get_arga(insn)
				local offset = get_argd(insn)
				local jumpTo = pc + offset
				pc += 1
				local aux = proto.code[pc]
				table.insert(output, string.format(
					"JUMPIFLE %i %i %i ; to %i\n",
					register1,
					aux,
					offset,
					jumpTo
				))
			elseif opcode == 0xB7 then -- JUMPIFLT
				local register1 = get_arga(insn)
				local offset = get_argd(insn)
				local jumpTo = pc + offset
				pc += 1
				local aux = proto.code[pc]
				table.insert(output, string.format(
					"JUMPIFLT %i %i %i ; to %i\n",
					register1,
					aux,
					offset,
					jumpTo
				))
			elseif opcode == 0x9A then -- JUMPIFNOTEQ
				local register1 = get_arga(insn)
				local offset = get_argd(insn)
				local jumpTo = pc + offset
				pc += 1
				local aux = proto.code[pc]
				table.insert(output, string.format(
					"JUMPIFNOTEQ %i %i %i ; to %i\n",
					register1,
					aux,
					offset,
					jumpTo
				))
			elseif opcode == 0x7D then -- JUMPIFNOTLE
				local register1 = get_arga(insn)
				local offset = get_argd(insn)
				local jumpTo = pc + offset
				pc += 1
				local aux = proto.code[pc]
				table.insert(output, string.format(
					"JUMPIFNOTLE %i %i %i ; to %i\n",
					register1,
					aux,
					offset,
					jumpTo
				))
			elseif opcode == 0x60 then -- JUMPIFNOTLT
				local register1 = get_arga(insn)
				local offset = get_argd(insn)
				local jumpTo = pc + offset
				pc += 1
				local aux = proto.code[pc]
				table.insert(output, string.format(
					"JUMPIFNOTLT %i %i %i ; to %i\n",
					register1,
					aux,
					offset,
					jumpTo
				))
			elseif opcode == 0x43 then -- ADD
				table.insert(output, string.format(
					"ADD %i %i %i\n",
					get_arga(insn),
					get_argb(insn),
					get_argc(insn)
				))
			elseif opcode == 0x26 then -- SUB
				table.insert(output, string.format(
					"SUB %i %i %i\n",
					get_arga(insn),
					get_argb(insn),
					get_argc(insn)
				))
			elseif opcode == 0x09 then -- MUL
				table.insert(output, string.format(
					"MUL %i %i %i\n",
					get_arga(insn),
					get_argb(insn),
					get_argc(insn)
				))
			elseif opcode == 0xEC then -- DIV
				table.insert(output, string.format(
					"DIV %i %i %i\n",
					get_arga(insn),
					get_argb(insn),
					get_argc(insn)
				))
			elseif opcode == 0xCF then -- MOD
				table.insert(output, string.format(
					"MOD %i %i %i\n",
					get_arga(insn),
					get_argb(insn),
					get_argc(insn)
				))
			elseif opcode == 0xB2 then -- POW
				table.insert(output, string.format(
					"POW %i %i %i\n",
					get_arga(insn),
					get_argb(insn),
					get_argc(insn)
				))
			elseif opcode == 0x95 then -- ADDK
				local constantIndex = get_argc(insn)
				local constantValue = proto.k[constantIndex + 1]
				table.insert(output, string.format(
					"ADDK %i %i %i ; K(%i) = %4.3f\n",
					get_arga(insn),
					get_argb(insn),
					constantIndex,
					constantIndex,
					constantValue
				))
			elseif opcode == 0x78 then -- SUBK
				local constantIndex = get_argc(insn)
				local constantValue = proto.k[constantIndex + 1]
				table.insert(output, string.format(
					"SUBK %i %i %i ; K(%i) = %4.3f\n",
					get_arga(insn),
					get_argb(insn),
					constantIndex,
					constantIndex,
					constantValue
				))
			elseif opcode == 0x5B then -- MULK
				local constantIndex = get_argc(insn)
				local constantValue = proto.k[constantIndex + 1]
				table.insert(output, string.format(
					"MULK %i %i %i ; K(%i) = %4.3f\n",
					get_arga(insn),
					get_argb(insn),
					constantIndex,
					constantIndex,
					constantValue
				))
			elseif opcode == 0x3E then -- DIVK
				local constantIndex = get_argc(insn)
				local constantValue = proto.k[constantIndex + 1]
				table.insert(output, string.format(
					"DIVK %i %i %i ; K(%i) = %4.3f\n",
					get_arga(insn),
					get_argb(insn),
					constantIndex,
					constantIndex,
					constantValue
				))
			elseif opcode == 0x21 then -- MODK
				local constantIndex = get_argc(insn)
				local constantValue = proto.k[constantIndex + 1]
				table.insert(output, string.format(
					"MODK %i %i %i ; K(%i) = %4.3f\n",
					get_arga(insn),
					get_argb(insn),
					constantIndex,
					constantIndex,
					constantValue
				))
			elseif opcode == 0x04 then -- POWK
				local constantIndex = get_argc(insn)
				local constantValue = proto.k[constantIndex + 1]
				table.insert(output, string.format(
					"POWK %i %i %i ; K(%i) = %4.3f\n",
					get_arga(insn),
					get_argb(insn),
					constantIndex,
					constantIndex,
					constantValue
				))
			elseif opcode == 0xE7 then -- AND
				table.insert(output, string.format(
					"AND %i %i %i\n",
					get_arga(insn),
					get_argb(insn),
					get_argc(insn)
				))
			elseif opcode == 0xCA then -- OR
				table.insert(output, string.format(
					"OR %i %i %i\n",
					get_arga(insn),
					get_argb(insn),
					get_argc(insn)
				))
			elseif opcode == 0xAD then -- ANDK
				local constantIndex = get_argc(insn)
				table.insert(output, string.format(
					"ANDK %i %i %i ; K(%i) = %s\n",
					get_arga(insn),
					get_argb(insn),
					constantIndex,
					constantIndex,
					getConstantString(proto.k[constantIndex + 1])
				))
			elseif opcode == 0x90 then -- ORK
				local constantIndex = get_argc(insn)
				table.insert(output, string.format(
					"ORK %i %i %i ; K(%i) = %s\n",
					get_arga(insn),
					get_argb(insn),
					constantIndex,
					constantIndex,
					getConstantString(proto.k[constantIndex + 1])
				))
			elseif opcode == 0x73 then -- CONCAT
				table.insert(output, string.format(
					"CONCAT %i %i %i\n",
					get_arga(insn),
					get_argb(insn),
					get_argc(insn)
				))
			elseif opcode == 0x56 then -- NOT
				table.insert(output, string.format(
					"NOT %i %i\n",
					get_arga(insn),
					get_argb(insn)
				))
			elseif opcode == 0x39 then -- MINUS
				table.insert(output, string.format(
					"MINUS %i %i\n",
					get_arga(insn),
					get_argb(insn)
				))
			elseif opcode == 0x1C then -- LENGTH
				table.insert(output, string.format(
					"LENGTH %i %i\n",
					get_arga(insn),
					get_argb(insn)
				))
			elseif opcode == 0xFF then -- NEWTABLE
				pc += 1
				local aux = proto.code[pc]
				table.insert(output, string.format(
					"NEWTABLE %i %i %i\n",
					get_arga(insn),
					get_argb(insn),
					aux
				))
			elseif opcode == 0xE2 then -- DUPTABLE
				table.insert(output, string.format(
					"DUPTABLE %i %i\n",
					get_arga(insn),
					get_argd(insn)
				))
			elseif opcode == 0xC5 then -- SETLIST
				local sourceStart = get_argb(insn)
				local argc = get_argc(insn)
				pc += 1
				local aux = proto.code[pc]
				table.insert(output, string.format(
					"SETLIST %i %i %i %i ; start at register %i, fill %s values, start at table index %i\n",
					get_arga(insn),
					sourceStart,
					argc,
					aux,
					sourceStart,
					argc ~= 0 and tostring(argc - 1) or "MULTRET",
					aux
				))
			elseif opcode == 0xA8 then -- FORNPREP
				local jumpOffset = get_argd(insn)
				table.insert(output, string.format(
					"FORNPREP %i %i ; to %i\n",
					get_arga(insn),
					jumpOffset,
					pc + jumpOffset
				))
			elseif opcode == 0x8B then -- FORNLOOP
				local jumpOffset = get_argd(insn)
				table.insert(output, string.format(
					"FORNLOOP %i %i ; to %i\n",
					get_arga(insn),
					jumpOffset,
					pc + jumpOffset
				))
			elseif opcode == 0x51 then -- FORGPREP_INEXT
				local jumpOffset = get_argd(insn)
				table.insert(output, string.format(
					"FORGPREP_INEXT %i %i ; to %i\n",
					get_arga(insn),
					jumpOffset,
					pc + jumpOffset
				))
			elseif opcode == 0x34 then -- FORGLOOP_INEXT
				local jumpOffset = get_argd(insn)
				table.insert(output, string.format(
					"FORGLOOP_INEXT %i %i ; to %i\n",
					get_arga(insn),
					jumpOffset,
					pc + jumpOffset
				))
			elseif opcode == 0x17 then -- FORGPREP_NEXT
				local jumpOffset = get_argd(insn)
				table.insert(output, string.format(
					"FORGPREP_NEXT %i %i ; to %i\n",
					get_arga(insn),
					jumpOffset,
					pc + jumpOffset
				))
			elseif opcode == 0xFA then -- FORGLOOP_NEXT
				local jumpOffset = get_argd(insn)
				table.insert(output, string.format(
					"FORGLOOP_NEXT %i %i ; to %i\n",
					get_arga(insn),
					jumpOffset,
					pc + jumpOffset
				))
			elseif opcode == 0xDD then -- GETVARARGS
				table.insert(output, string.fomrat(
					"GETVARARGS %i %i\n",
					get_arga(insn),
					get_argb(insn)
				))
			elseif opcode == 0xC0 then -- DUPCLOSURE
				local childProtoId = get_argd(insn)
				table.insert(output, string.format(
					"DUPCLOSURE %i %i ; global id = %i\n",
					get_arga(insn),
					childProtoId,
					proto.k[childProtoId + 1]
				))
			elseif opcode == 0xA3 then -- PREPVARARGS
				table.insert(output, "PREPVARARGS " .. get_arga(insn) .. "\n")
			elseif opcode == 0x86 then -- LOADKX
				pc += 1
				local aux = proto.code[pc]
				table.insert(output, string.format(
					"LOADKX %i %i\n",
					get_arga(insn),
					aux
				))
			elseif opcode == 0x69 then -- JUMPX
				local offset = get_arge(insn)
				table.insert(output, string.format(
					"JUMPX %i ; to %i\n",
					offset,
					pc + offset
				))
			elseif opcode == 0x4C then -- FASTCALL
				table.insert(output, string.format(
					"FASTCALL %i %i\n",
					get_arga(insn),
					get_argc(insn)
				))
			elseif opcode == 0x2F then -- COVERAGE
				table.insert(output, "COVERAGE\n")
			elseif opcode == 0x12 then -- CAPTURE
				local captureTypeId = get_arga(insn)
				table.insert(output, string.format(
					"CAPTURE %i %i ; %s capture\n",
					captureTypeId,
					get_argb(insn),
					CAPTURE_TYPES[captureTypeId] or "unknown"
				))
			elseif opcode == 0xF5 then -- JUMPIFEQK
				local offset = get_argd(insn)
				local jumpTo = pc + offset
				pc += 1
				local aux = proto.code[pc]
				table.insert(output, string.format(
					"JUMPIFEQK %i %i %i ; K(%i) = %s, to %i\n",
					get_arga(insn),
					aux,
					offset,
					aux,
					getConstantString(proto.k[aux + 1]),
					jumpTo
				))
			elseif opcode == 0xD8 then -- JUMPIFNOTEQK
				local offset = get_argd(insn)
				local jumpTo = pc + offset
				pc += 1
				local aux = proto.code[pc]
				table.insert(output, string.format(
					"JUMPIFNOTEQK %i %i %i ; K(%i) = %s, to %i\n",
					get_arga(insn),
					aux,
					offset,
					aux,
					getConstantString(proto.k[aux + 1]),
					jumpTo
				))
			elseif opcode == 0xBB then -- FASTCALL1
				local offset = get_argc(insn)
				table.insert(output, string.format(
					"FASTCALL1 %i %i %i ; to %i\n",
					get_arga(insn),
					get_argb(insn),
					offset,
					pc + offset
				))
			elseif opcode == 0x9E then -- FASTCALL2
				local offset = get_argc(insn)
				pc += 1
				local aux = proto.code[pc]
				table.insert(output, string.format(
					"FASTCALL2 %i %i %i %i ; to %i\n",
					get_arga(insn),
					get_argb(insn),
					aux,
					offset,
					pc + offset
				))
			elseif opcode == 0x81 then -- FASTCALL2K
				local offset = get_argc(insn)
				pc += 1
				local aux = proto.code[pc]
				table.insert(output, string.format(
					"FASTCALL2K %i %i %i %i ; to %i\n",
					get_arga(insn),
					get_argb(insn),
					aux,
					offset,
					pc + offset
				))
			else -- Unknown opcode
				table.insert(output, string.format(
					"UNKNOWN (%#010x)\n",
					insn
				))
			end

			pc += 1
		end
	end

	return table.concat(output, "")
end 

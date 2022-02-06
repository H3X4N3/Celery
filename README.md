# Celery<br>
These are a few needed resources for Celery.<br>

CELERY DISCORD INVITE: <br>

https://discord.gg/nXu4FENMPj<br>


# Functions / Documentation<br>


I. Miscellaneous<br>
II. IO<br>
III. Drawing Library<br>
IV. Debug Library<br>
V. Raknet/"rnet"<br>


# I. Miscellaneous Functions<br>


`String identifyexecutor()`
Returns a string to identify what executor is being used. In this case, it's "Celery". Example:<br>
```lua
if ({pcall(identifyexecutor)})[2] == "Celery" then
    print'Using Celery'
end
```


`Table getrenv()` --> Returns the roblox script environment


`Table getgenv()` --> Defaults to getfenv(). There is no way to implement this in Celery because roblox automatically sandboxes and protects each script environment for us -- so, there is no reason to use this function in Celery.


`Table getreg()` --> Returns a table containing all elements stored in lua registry.


`Int32 getidentity()` --> Returns the context level of execution that the script is running with.


`void setidentity(Int32 identity)` --> Sets the current context level to `identity`


`Boolean iscclosure(Function f)` --> Returns true is `f` is a C closure and not a Lua function


`Function newcclosure(Function f)` --> Returns a C closure function which invokes the lua function `f`


`Boolean isreadonly(Table t)` --> Returns whether the table `t` is read only.


`void setreadonly(Table t, Boolean value)` --> Sets whether the table `t` is read only or not


`void makereadonly(Table t)` --> Sets table `t` to read only


`void makewriteable(Table t)` --> Makes the table `t` write-able (not read only)


`Function hookfunction(Function a, Function b)` --> Swaps the internal function of `a` with `b`, so every time `a` is called it will call `b` instead. Returns the old `a` function.


`String getnamecallmethod()` --> Returns the current namecall method used by `__namecall`, as a string


`void setnamecallmethod(String method)` --> Sets the current namecall method used by `__namecall` to `method`


`Table getrawmetatable(Table t)` --> Returns the raw metatable of `t` -- basically just bypasses the `__metatable` check for it


`Table gethiddenproperties(Instance instance)` --> Returns hidden lua properties associated with `instance`


`String getscriptbytecode(Instance localscript)` --> Returns the luau bytecode contained in the localscript `localscript`. ModuleScripts are not supported yet


`String disassemble(String bytecode)` --> Translates a script's bytecode into a readable, disassembled output.


`String decompile(Instance localscript)` --> Decompiles a localscript's bytecode into readable lua, as close to the original script as possible. 


`void fireclickdetector(ClickDetector instance)` --> Fires the clickdetector instance -- calling any signals connected to it


`void firetouchinterest(Instance a, BasePart b, Int32 mode)` --> Fires a parts touchinterest


`void sethiddenproperty(Instance instance, String property, Variant value)` --> Sets the hidden property `property` of `instance` to `value`


`Variant gethiddenproperty(Instance instance, String property)` --> Gets the hidden property `property` from `instance`


`Number getsimulationradius()` --> Returns your client's simulation radius


`void setsimulationradius(Number value)` --> Sets your client's simulation radius to `value`







# II. IO Functions<br>

`String readfile(String filepath)` --> Reads the content of the file as a string. This works with plain-text and binary files.


`void writefile(String filepath, String content)` --> Writes the string `content` to the file located at `filepath`. Only string content is supported.


`String getclipboard()` --> Returns any text that was saved to your clipboard (typically from doing Ctrl+C)


`void setclipboard(String text)` --> Stores `text` in your clipboard


`String httpget(String url)` --> Reads the content at `url` as a plain-text string.


`syn.request` --> Refer to synapse docs


Deprecation note:<br>
game:HttpGet is supported for legacy reasons. It should not be used, since it has been fully removed from roblox for a couple of years now. Either use celery's `httpget` or `syn.request`


Self-explanatory IO functions which are supported:

`void mouse1down()`
`void mouse1up()`
`void mouse1click()`
`void mouse2down()`
`void mouse2up()`
`void mouse2click()`
`void presskey()`
`void releasekey()`



# III. Drawing Functions<br>


`Instance Drawing.new(String classname)` --> Creates a new drawing object. Supported types:
`text`, `line`, `triangle`, `square`, `circle`, `quad`



# IV. Debug Functions<br>


`Variant debug.getconstant(Function f, Int32 index)` --> Returns the constant at `index` from the function `f`'s constants

`Function debug.getproto(Function f, Int32 index)` --> Returns the proto at `index` from the function `f`'s protos

`Int32 debug.getcode(Function f, Int32 index)` --> Returns the instruction at `index` from function `f`'s code

`Variant debug.getstack(Int32 index)` --> Returns the element at `index` from the current function's stack.

`Variant debug.getupvalue(Function f, Int32 index)` --> Returns the upvalue at `index` from the function `f`'s upvalues

`Table debug.getconstants(Function f)` --> Returns the constants used in function `f`

`Table debug.getprotos(Function f)` --> Returns the protos used in function `f`

`Table debug.getcode(Function f)` --> Returns the instructions in function `f`'s code

`Table debug.getstack()` --> Returns all elements in the current thread's stack

`Table debug.getupvalues(Function f)` --> Returns the upvalues in the function `f`


`void debug.setconstants(Function f, Table constants)` --> Sets the constants used in function `f` to the table `constants`

`void debug.setprotos(Function f, Table protos)` --> Sets the protos used in function `f` to the table `protos`

`void debug.setcode(Function f, Table code)` --> Set the instructions in function `f` to `code` (Disabled unless you are in experimental mode)

`void debug.setstack(Table stack)` --> Sets the current thread's stack to `stack`

`void debug.setupvalues(Function f, Table upvalues)` --> Sets the upvalues in the function `f` to `upvalues`

`void debug.setconstant(Function f, Int32 index, Variant constant)` --> Sets the constant at `index` from function `f` to `constant`

`void debug.setproto(Function f, Int32 index, Function proto)` --> Sets the proto at `index` from the function `f`'s protos to `proto`

`void debug.setcode(Function f, Int32 index, Int32 instruction)` --> Sets the instruction at `index` from function `f`'s code to `instruction`

`void debug.setstack(Int32 index, Variant value)` --> Sets the element at `index` from the current function's stack to `value`

`void debug.setupvalue(Function f, Int32 index, Variant value)` --> Sets the upvalue at `index` from the function `f`'s upvalues to `value`


<br>
Disclaimer #1:<br>
Synapse claims that there's an ACE vulnerability but they won't provide any evidence of what was involved to actually execute shell-code. The possibility of such a thing happening, when you have more than usual sanitization checks, would rely on external means or another custom function that is apparently flawed. Until this _other_ function is uncovered and the ACE is actually proven not by some staged video, the actual cause of the ACE is unknown, and I will not remove my debug library<br>
<br>
Disclaimer #2:<br>
Use obfuscated scripts at your own risk, since any obfuscated script can destroy your PC at any given time, and even synapse cannot fully prevent this. Use obfuscated scripts only if they're from a TRUSTED source. I will not take responsibility for it<br>


# V. rnet (Raknet) API<br>


`void rnet.sendposition(Vector3 value)` --> Tells the server to locate your character at the position `value`


`void rnet.startcapture()` --> Displays outgoing packets in Celery's debug console


`void rnet.stopcapture()` --> Stops outgoing packets from being displayed


`void rnet.setfilter(Table t)` --> Sets a packet filter of packets to be ignored, or completely blocked. The first couple of bytes in the packet will be compared with the bytes in `t`. If a packet starts with 1B and you run `rnet.setfilter({0x1B})` then the packet will be blocked. Use `rnet.setfilter({})` to clear this filter.


`Signal rnet.Capture` --> This event allows you to view/log packets yourself, to display them however you want. Here is an example of its usage:
```lua
local packetViewer = rnet.Capture:Connect(function(packet)
    print("Sent packet:")
    local str = "";
    for _,v in pairs(packet.data) do
        str = str .. string.format("%02X ", v);
    end
    print("Sending packet. ID: " .. string.format("%02X", packet.id) .. ". Full packet:");
    print(str);
    print("\n");
end)

wait(30);
packetViewer:disconnect();
```


`void rnet.sendraw(String|Table value)` --> Sends a packet to the ROBLOX network, either by a hex-formatted String or a Table of bytes.










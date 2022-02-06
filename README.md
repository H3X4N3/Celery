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

identifyexecutor()<br>
Returns a string to identify what executor is being used. In this case, it's "Celery". Example:<br>
```lua
if ({pcall(identifyexecutor)})[2] == "Celery" then
    print'Using Celery'
end
```


`getrenv()`
Returns the roblox script environment


`getgenv()`
Defaults to getfenv(). There is no way to implement this in Celery because roblox automatically sandboxes and protects each script environment for us -- so, there is no reason to use this function in Celery.


`getreg()`
Returns a table containing all elements stored in lua registry.


`getidentity()`
Returns the context level of execution that the script is running with.


`setidentity(Int32 identity)`
Sets the current context level to `identity`


`iscclosure(Function f)`
Returns true is `f` is a C closure and not a Lua function


`newcclosure(Function f)`
Returns a C closure function which invokes the lua function `f`


`isreadonly(Table t)`
Returns whether the table `t` is read only.


`setreadonly(Table t, Boolean value)`
Returns whether the table `t` is read only.





# II. IO Functions<br>

`readfile(String filepath)`
Returns the contents of the file as a string. This works with plain-text and binary files.


`writefile(String filepath, String content)`
Writes the string `content` to the file located at `filepath`. Only string content is supported.


`syn.request`
Refer to synapse docs


Note:<br>
game:HttpGet is supported but it should not be used, it's deprecated and has been fully removed from roblox, for a couple years now. Either use celery's `httpget` or use `syn.request`


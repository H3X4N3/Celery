# Celery
These are a few needed resources for Celery.

CELERY DISCORD INVITE: 

https://discord.gg/nXu4FENMPj

# Functions / Documentation

I. Miscellaneous
II. IO
III. Drawing Library
IV. Debug Library
V. Raknet/"rnet"

# I. Miscellaneous Functions

identifyexecutor()
Returns a string to identify what executor is being used. In this case, it's "Celery"
```lua
if ({pcall(identifyexecutor)})[2] == "Celery" then
    print'Using Celery'
end
```


# II. IO Functions

readfile(String filepath)
Returns the contents of the file as a string. This also works with binary files.

writefile(String filepath, String content)
Writes the content (only a string is accepted) to the file located at filepath







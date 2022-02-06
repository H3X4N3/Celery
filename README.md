# Celery
These are a few needed resources for Celery.

CELERY DISCORD INVITE: 

https://discord.gg/nXu4FENMPj

# Functions

identifyexecutor
Returns a string to identify what executor is being used. In this case, it's "Celery"
[code]
if ({pcall(identifyexecutor)})[2] == "Celery" then
    print'Using Celery'
end
[/code]


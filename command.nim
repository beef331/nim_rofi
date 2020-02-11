import interfaced
import strformat
import osproc
import os

createInterface(Cmd):
    proc invoke*(this: Cmd)
    proc niceName*(this: Cmd): string

type
    #Only using base class for nicename
    BaseCmd = ref object of RootObj
        niceName*: string

    Game* = ref object of BaseCmd
        name*: string
        id*: int
        runner*: string
        dir*: string

    Run* = ref object of BaseCmd
        command*: proc()

var 
    addCommand*:proc(self : Cmd)

#Implementing interface
proc niceName(self: Game): string = self.niceName
proc niceName(self: Run): string = self.niceName

proc invoke*(self: Game) =
    echo fmt"Start Game {self.niceName}"
    discard execProcess(fmt"lutris lutris:rungame/{$self.name}")

proc invoke*(self: Run) =
    self.command()

Game.impl(Cmd)
Run.impl(Cmd)
#

#Constructors
proc newGame*(niceName: string, name: string, id: int, runner: string, dir: string): Game =
    let game = Game(niceName: niceName, name: name, id: id, runner: runner, dir: dir)
    addCommand(game.toCmd)
    return game

proc newRun*(niceName: string, command: proc()): Run =
    let run = Run(niceName: niceName,command : command)
    addCommand(run.toCmd)
    return run

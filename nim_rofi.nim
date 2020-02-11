import command
import osproc
import strformat
import strutils
import json
import tables

var
    commandTable = initOrderedTable[string, Cmd]()
let
    gameList = execProcess("lutris -l -j", "./")
    jsonString = "[" & gameList.split('[')[1].split(']')[0] & "]"
    parsed = parseJson(jsonString)

proc getCommandString(list: OrderedTable[string, Cmd]): string =
    var first: bool = true
    for x in list.keys:
        var line: string
        if(not first): line = "\n"
        first = false
        line &= list[x].niceName
        result &= line

proc parseGames() =
    for x in parsed:
        let game = newGame(x["name"].getStr(), x["slug"].getStr(), x["id"].getInt(), x["runner"].getStr(), x["directory"].getStr())
        command.games.add(game)

proc addCommand*(cmd : Cmd)=
    commandTable[cmd.niceName] = cmd

proc displayCommands() =
    var response: string = execProcess(fmt"echo '{getCommandString(commandTable)}'| rofi -dmenu").replace("\n", "")
    commandTable[response].invoke()

proc gameCommands() =
    commandTable.clear()
    parseGames()
    discard newRun("Kill all Lutris Wine", command.killAll)
    displayCommands()

proc nimShowOff()=
    commandTable.clear()
    for x in countup(0,10):
        discard newRun(fmt"Hello Nim humans {x}", nil)
    displayCommands()

proc baseCommands()=
    commandTable.clear()
    discard newRun("Game Commands", gameCommands)
    discard newRun("Nim Showoff",nimShowOff)
    displayCommands()

command.addCommand = addCommand

baseCommands()

import osproc
import os
import strformat
import strutils
import json
import tables
import xmlparser,httpclient,xmltree,browsers,nre,htmlparser

const docsUrl = "https://nim-lang.org/docs/"

type
    CommandKind = enum
        ckCommand,
        ckLutris
    Command = object
        niceName: string
        case kind: CommandKind
        of ckCommand:
            command*: proc(args : seq[string])
            args*: seq[string]
        of ckLutris:
            name*: string
            id*: int
            runner*: string
            dir*: string

var
    commandTable = initOrderedTable[string, Command]()
    games: seq[Command]


proc initLutris(niceName, name, runner, dir: string, id: int): Command=
    result = Command(kind: ckLutris, niceName : niceName, name : name, runner: runner, dir : dir, id : id)
    commandTable.add(niceName,result)

proc initCommand(niceName: string, command : proc(args : seq[string]), args : seq[string] = @[]):Command=
    result = Command(kind: ckCommand, niceName: niceName, command: command, args: args)
    commandTable.add(niceName, result)

proc invoke(cmd: Command)=
    case cmd.kind:
    of ckCommand: cmd.command(cmd.args)
    of ckLutris: discard execProcess(fmt"lutris lutris:rungame/{$cmd.name}")

proc getCommandString(list: OrderedTable[string, Command]): string =
    var first: bool = true
    for x in list.keys:
        var line: string
        if(not first): line = "\n"
        first = false
        line &= list[x].niceName
        result &= line

proc killAll*(a : seq[string]) =
    for x in games:
        putEnv("WINEPREFIX", x.dir)
        discard execProcess("wineserver -k")

proc parseGames(parsed :JsonNode) =
    for x in parsed:
        let game = initLutris(x["name"].getStr(), x["slug"].getStr(), x["runner"].getStr(), x["directory"].getStr(), x["id"].getInt())
        games.add(game)

proc addCommand*(Command : Command)=
    commandTable[Command.niceName] = Command

proc displayCommands(title, mesg: string = "") =
    var command = "rofi -i -levenshtein-sort -dmenu"

    if(not title.isEmptyOrWhitespace()):
        command = &"{command} -p \"{title}\""
    if(not mesg.isEmptyOrWhitespace()):
        command = &"{command} -mesg \"{mesg}\""
    
    echo command

    var response: string = execProcess(fmt"echo '{getCommandString(commandTable)}'| {command}").replace("\n", "")
    if(commandTable.contains(response)):
        commandTable[response].invoke()


proc openDoc(a : seq[string])
proc getDocPage(a : seq[string])
proc nimDocs(a : seq[string])
proc baseCommands()

proc gameCommands(a : seq[string]) =
    let gameList = execProcess("lutris -l -j", "./")
    let jsonString = "[" & gameList.split('[')[1].split(']')[0] & "]"
    let parsed = parseJson(jsonString)
    commandTable.clear()
    parseGames(parsed)
    discard initCommand("Kill all Lutris Wine", killAll)
    discard initCommand("Back To Main", proc(a:seq[string]) = baseCommands())
    displayCommands("Lutris Games")



proc openDoc(a : seq[string])=
    openDefaultBrowser(docsUrl & a[0])

proc getDocPage(a : seq[string])=
    commandTable.clear()
    var client = newHttpClient()
    var response = parseHtml(client.get(docsUrl & a[0]).bodyStream)
    for ul in  response.findAll("ul"):
        if(ul.attr("id") == "toc-list"):
            for linked in ul.findAll("a"):
                discard initCommand(linked.innerText, openDoc, @[a[0] & linked.attr("href")])
    discard initCommand("Back To Modules", nimDocs)
    discard initCommand("Back To Main", proc(a:seq[string]) = baseCommands())
    displayCommands(a[0].split(".")[0])

proc nimDocs(a : seq[string])=
    commandTable.clear()
    var client = newHttpClient()
    var response = (client.get(fmt"{docsUrl}theindex.html").body())
    var pattern = re"<p /?>*.*<p />"
    var find = response.find(pattern)

    if(find.isSome):
        var captured  = (response[find.get().captureBounds[-1]])
        captured[3] = ' '
        captured = captured.replace("<p />","</p>")
        var xmlParsed = parseXml(captured)
        for a in xmlParsed.findAll("a"):
            discard initCommand(a.innerText,getDocPage, @[a.attr("href")])
    discard initCommand("Back To Main", proc(a:seq[string]) = baseCommands())
    displayCommands("Nim Docs")

proc baseCommands()=
    commandTable.clear()
    discard initCommand("Game Commands", gameCommands)
    discard initCommand("Nim Documentation",nimDocs)
    displayCommands("Nim Rofi")

baseCommands()

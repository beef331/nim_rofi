import 
    std/[
        osproc, os,
        strformat,
        strutils,
        json, tables,
        xmlparser,
        httpclient,
        xmltree,
        browsers,
        nre,
        htmlparser
    ]

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
    ##Does the logic applied for the object variants
    case cmd.kind:
    of ckCommand: cmd.command(cmd.args)
    of ckLutris: discard execProcess(fmt"lutris lutris:rungame/{$cmd.name}")

proc getCommandString(list: OrderedTable[string, Command]): string =
    ##Generates the string to be sent to rofi
    var first: bool = true
    for x in list.keys:
        var line: string
        if(not first): line = "\n"
        first = false
        line &= list[x].niceName
        result &= line

proc killAll(a : seq[string]) =
    for x in games:
        putEnv("WINEPREFIX", x.dir)
        discard execProcess("wineserver -k")

proc parseGames(parsed :JsonNode) =
    for x in parsed:
        let game = initLutris(x["name"].getStr(), x["slug"].getStr(), x["runner"].getStr(), x["directory"].getStr(), x["id"].getInt())
        games.add(game)

proc displayCommands(title, mesg: string = "") =
    ##Takes in title, mesg which are strings for what to promt the user with
    ##Title is displayed on the input line, message as a sub title
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
    ##Parses the lutris JSON data and puts it in a command version
    let gameList = execProcess("lutris -l -j", "./")
    let jsonString = "[" & gameList.split('[')[1].split(']')[0] & "]"
    let parsed = parseJson(jsonString)
    commandTable.clear()
    parseGames(parsed)
    discard initCommand("Kill all Lutris Wine", killAll)
    discard initCommand("Back To Main", proc(a:seq[string]) = baseCommands())
    displayCommands("Lutris Games")

proc openDoc(a : seq[string])=
    ##Does what it says on the tin, opens the browser to the document
    openDefaultBrowser(docsUrl & a[0])

proc getDocPage(a : seq[string])=
    ##Gets the symbols from the doc page, 
    ##all the HTML <a> on the left of the moduel
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
    ##Function that gets and parsed the nim modules, and then setups the URL
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
    ##Main function that starts the UI experience
    commandTable.clear()
    discard initCommand("Game Commands", gameCommands)
    discard initCommand("Nim Documentation",nimDocs)
    displayCommands("Nim Rofi")

baseCommands()

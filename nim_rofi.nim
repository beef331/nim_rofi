import command
import osproc
import os
import strformat
import strutils
import json
import tables
import xmlparser,httpclient,xmltree,browsers,nre,htmlparser

const docsUrl = "https://nim-lang.org/docs/"

var
    commandTable = initOrderedTable[string, Cmd]()
    games*: seq[Game]
    nimDocProc : proc(a : seq[string])

proc getCommandString(list: OrderedTable[string, Cmd]): string =
    var first: bool = true
    for x in list.keys:
        var line: string
        if(not first): line = "\n"
        first = false
        line &= list[x].niceName
        result &= line

proc killAll*(a : seq[string]) =
    echo "Kill all"
    for x in games:
        putEnv("WINEPREFIX", x.dir)
        discard execProcess("wineserver -k")

proc parseGames(parsed :JsonNode) =
    for x in parsed:
        let game = newGame(x["name"].getStr(), x["slug"].getStr(), x["id"].getInt(), x["runner"].getStr(), x["directory"].getStr())
        games.add(game)

proc addCommand*(cmd : Cmd)=
    commandTable[cmd.niceName] = cmd

proc displayCommands() =
    var response: string = execProcess(fmt"echo '{getCommandString(commandTable)}'| rofi -dmenu").replace("\n", "")
    commandTable[response].invoke()

proc gameCommands(a : seq[string]) =
    let gameList = execProcess("lutris -l -j", "./")
    let jsonString = "[" & gameList.split('[')[1].split(']')[0] & "]"
    let parsed = parseJson(jsonString)
    commandTable.clear()
    parseGames(parsed)
    discard newRun("Kill all Lutris Wine", killAll)
    displayCommands()

proc openDoc(a : seq[string])=
    openDefaultBrowser(docsUrl & a[0])

proc getDocPage(a : seq[string])=
    commandTable.clear()
    var client = newHttpClient()
    var response = parseHtml(client.get(docsUrl & a[0]).bodyStream)
    #var find = response.child("ul")
    for ul in  response.findAll("ul"):
        if(ul.attr("id") == "toc-list"):
            for linked in ul.findAll("a"):
                var run = newRun(linked.innerText,openDoc)
                run.args.add(a[0] & linked.attr("href"))
    discard newRun("Back To Modules", nimDocProc)
    displayCommands()

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
            var run = newRun(a.innerText,getDocPage)
            run.args.add(a.attr("href"))

    displayCommands()

proc baseCommands()=
    commandTable.clear()
    discard newRun("Game Commands", gameCommands)
    discard newRun("Nim Documentation",nimDocs)
    displayCommands()

command.addCommand = addCommand
nimDocProc = nimDocs
baseCommands()

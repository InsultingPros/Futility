/**
 *  Command for managing trader time and traders.
 *      Copyright 2021-2022 Anton Tarasenko
 *------------------------------------------------------------------------------
 * This file is part of Acedia.
 *
 * Acedia is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License, or
 * (at your option) any later version.
 *
 * Acedia is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Acedia.  If not, see <https://www.gnu.org/licenses/>.
 */
class ACommandTrader extends Command;

var private ACommandTrader_Announcer announcer;

var protected const int TLIST, TOPEN, TCLOSE, TENABLE, TDISABLE, TAUTO_OPEN;
var protected const int TTRADER, TTRADERS, TALL, TAUTO_OPEN_QUESTION, TQUOTE;
var protected const int TAUTO_OPEN_FLAG, TDISABLED_FLAG, TUNKNOWN_TRADERS;
var protected const int TLIST_TRADERS, TCOMMA_SPACE, TSELECTED_FLAG;
var protected const int TPARENTHESIS_OPEN, TPARENTHESIS_CLOSE;
var protected const int TSELECT, TIGNORE_DOORS, TBOOT, TTRADER_TIME, TTIME;
var protected const int TIGNORE_PLAYERS, TPAUSE, TUNPAUSE, TCANNOT_PARSE_PARAM;
var protected const int TCLOSEST, TSPACE;

protected function Finalizer()
{
    _.memory.Free(announcer);
    super.Finalizer();
}

protected function BuildData(CommandDataBuilder builder)
{
    builder.Name(T(TTRADER)).Group(P("gameplay"))
        .Summary(P("Manages trader time and available traders."))
        .Describe(P("Enables of disables trading."))
        .ParamBoolean(T(TENABLE));
    builder.SubCommand(T(TTIME))
        .Describe(F("Changes current trader time if numeric value is specified."
            @ "You can also pause trader countdown by specifying"
            @ "{$TextEmphasis pause} or turn it back on with"
            @ "{$TextEmphasis unpause}."))
        .ParamText(T(TTRADER_TIME));
    builder.SubCommand(T(TLIST))
        .Describe(P("Lists names of all available traders and"
            @ "marks closest one to the caller."));
    builder.SubCommand(T(TOPEN))
        .Describe(P("Opens specified traders."))
        .OptionalParams()
        .ParamTextList(T(TTRADERS));
    builder.SubCommand(T(TCLOSE))
        .Describe(P("Closes specified traders."))
        .OptionalParams()
        .ParamTextList(T(TTRADERS));
    builder.SubCommand(T(TAUTO_OPEN))
        .Describe(P("Sets whether specified traders are open automatically."))
        .ParamBoolean(T(TAUTO_OPEN_QUESTION))
        .OptionalParams()
        .ParamTextList(T(TTRADERS));
    builder.SubCommand(T(TSELECT))
        .Describe(P("Selects specified trader."))
        .OptionalParams()
        .ParamText(T(TTRADER));
    builder.SubCommand(T(TBOOT))
        .Describe(P("Boots all players from specified traders. If no traders"
            @ "were specified - assumes that all of them should be affected."))
        .OptionalParams()
        .ParamTextList(T(TTRADERS));
    builder.SubCommand(T(TENABLE))
        .Describe(P("Enables specified traders."))
        .OptionalParams()
        .ParamTextList(T(TTRADERS));
    builder.SubCommand(T(TDISABLE))
        .Describe(P("Disables specified traders."))
        .OptionalParams()
        .ParamTextList(T(TTRADERS));
    builder.Option(T(TALL))
        .Describe(P("If sub-command targets shops, this flag will make it"
            @ "target all the available shops."));
    builder.Option(T(TCLOSEST))
        .Describe(P("If sub-command targets shops, this flag will make it also"
            @ "target closest shop to the caller."));
    builder.Option(T(TIGNORE_DOORS))
        .Describe(F("When used with {$TextEmphasis select} sub-command, it will"
            @ "neither open or close doors."));
    builder.Option(T(TIGNORE_PLAYERS), P("I"))
        .Describe(P("Normally commands that close doors will automatically boot"
            @ "players from inside to prevent locking them in. This flag forces"
            @ "this command to leave players inside. However they can still be"
            @ "booted out at the end of trading time. Also it is impossible to"
            @ "disable the trader and not boot players inside it."));
    announcer = ACommandTrader_Announcer(
        _.memory.Allocate(class'ACommandTrader_Announcer'));
}

protected function Executed(CallData arguments, EPlayer instigator)
{
    local bool newTradingStatus;

    announcer.Setup(none, instigator, othersConsole);
    if (arguments.subCommandName.IsEmpty())
    {
        newTradingStatus = arguments.parameters.GetBool(T(TENABLE));
        if (    arguments.parameters.GetBool(T(TENABLE))
            ==  _server.kf.trading.IsTradingActive())
        {
            announcer.AnnounceTradingNoChange();
        }
        _server.kf.trading.SetTradingStatus(newTradingStatus);
        if (newTradingStatus) {
            announcer.AnnounceActivatedTrading();
        }
        else {
            announcer.AnnounceDeactivatedTrading();
        }
    }
    else if (arguments.subCommandName.Compare(T(TLIST))) {
        ListTradersFor(instigator);
    }
    else if (arguments.subCommandName.Compare(T(TTIME), SCASE_INSENSITIVE)) {
        HandleTraderTime(arguments);
    }
    else if (arguments.subCommandName.Compare(T(TOPEN), SCASE_INSENSITIVE)) {
        SetTradersOpen(true, arguments, instigator);
    }
    else if (arguments.subCommandName.Compare(T(TCLOSE), SCASE_INSENSITIVE)) {
        SetTradersOpen(false, arguments, instigator);
    }
    else if (arguments.subCommandName.Compare(T(TSELECT), SCASE_INSENSITIVE)) {
        SelectTrader(arguments, instigator);
    }
    else if (arguments.subCommandName.Compare(T(TBOOT), SCASE_INSENSITIVE)) {
        BootFromTraders(arguments, instigator);
    }
    else if (arguments.subCommandName.Compare(T(TENABLE), SCASE_INSENSITIVE)) {
        SetTradersEnabled(true, arguments, instigator);
    }
    else if (arguments.subCommandName.Compare(T(TDISABLE), SCASE_INSENSITIVE)) {
        SetTradersEnabled(false, arguments, instigator);
    }
    else if (arguments.subCommandName.Compare(T(TAUTO_OPEN), SCASE_INSENSITIVE))
    {
        SetTradersAutoOpen(arguments, instigator);
    }
}

protected function ListTradersFor(EPlayer target)
{
    local int               i;
    local ETrader           closestTrader;
    local array<ETrader>    availableTraders;
    if (target == none) {
        return;
    }
    availableTraders = _server.kf.trading.GetTraders();
    callerConsole.Flush()
        .UseColorOnce(_.color.TextEmphasis).Write(T(TLIST_TRADERS));
    closestTrader = FindClosestTrader(target);
    for (i = 0; i < availableTraders.length; i += 1)
    {
        WriteTrader(availableTraders[i],
                    availableTraders[i].SameAs(closestTrader));
        if (i != availableTraders.length - 1) {
            callerConsole.Write(T(TCOMMA_SPACE));
        }
    }
    _.memory.Free(closestTrader);
    _.memory.FreeMany(availableTraders);
    callerConsole.Flush();
}

protected function HandleTraderTime(CallData result)
{
    local bool      oldIsPaused, newIsPaused;
    local int       countDownValue;
    local Text      parameter;
    local Parser    parser;
    parameter = result.parameters.GetText(T(TTRADER_TIME));
    if (parameter.Compare(T(TPAUSE), SCASE_INSENSITIVE))
    {
        oldIsPaused = _server.kf.trading.IsCountDownPaused();
        if (!oldIsPaused) {
            _server.kf.trading.SetCountdownPause(true);
        }
        newIsPaused = _server.kf.trading.IsCountDownPaused();
        if (oldIsPaused != newIsPaused) {
            announcer.AnnouncePausedTime();
        }
        return;
    }
    else if (parameter.Compare(T(TUNPAUSE), SCASE_INSENSITIVE))
    {
        oldIsPaused = _server.kf.trading.IsCountDownPaused();
        if (oldIsPaused) {
            _server.kf.trading.SetCountdownPause(false);
        }
        newIsPaused = _server.kf.trading.IsCountDownPaused();
        if (oldIsPaused != newIsPaused) {
            announcer.AnnounceUnpausedTime();
        }
        return;
    }
    parser = _.text.Parse(parameter);
    if (parser.MInteger(countDownValue).Ok())
    {
        _server.kf.trading.SetCountdown(countDownValue);
        announcer.AnnounceChangedCountdown(_server.kf.trading.GetCountdown());
    }
    else
    {
        callerConsole
            .UseColor(_.color.TextFailure)
            .Write(T(TCANNOT_PARSE_PARAM))
            .WriteLine(parameter)
            .ResetColor();
    }
    parser.FreeSelf();

}

protected function SetTradersOpen(
    bool        doOpen,
    CallData    result,
    EPlayer     callerPlayer)
{
    local int               i;
    local bool              needToBootPlayers;
    local array<ETrader>    selectedTraders;
    local Text              nextTraderName;
    local ListBuilder       affectedTraders;

    affectedTraders = ListBuilder(_.memory.Allocate(class'ListBuilder'));
    selectedTraders = GetTradersArray(result, callerPlayer);
    needToBootPlayers = !doOpen
        && !result.options.HasKey(T(TIGNORE_PLAYERS));
    for (i = 0; i < selectedTraders.length; i += 1)
    {
        if (selectedTraders[i].IsOpen() != doOpen)
        {
            nextTraderName = selectedTraders[i].GetName();
            affectedTraders.Item(nextTraderName);
            _.memory.Free(nextTraderName);
        }
        selectedTraders[i].SetOpen(doOpen);
        if (needToBootPlayers) {
            selectedTraders[i].BootPlayers();
        }
    }
    if (doOpen) {
        announcer.AnnounceTradersOpened(affectedTraders);
    }
    else {
        announcer.AnnounceTradersClosed(affectedTraders);
    }
    _.memory.FreeMany(selectedTraders);
    _.memory.Free(affectedTraders);
}

protected function bool AreTradersSame(ETrader trader1, ETrader trader2)
{
    if (trader1 == none && trader2 == none) return true;
    if (trader1 == none && trader2 != none) return false;
    if (trader1 != none && trader2 == none) return false;

    return trader1.SameAs(trader2);
}

protected function SelectTrader(CallData result, EPlayer callerPlayer)
{
    local Text      specifiedTraderName;
    local ETrader   previouslySelectedTrader, newlySelectedTrader;

    previouslySelectedTrader = _server.kf.trading.GetSelectedTrader();
    specifiedTraderName = result.parameters.GetText(T(TTRADER));
    //  Try to get trader user want to select:
    //  first try closes (if option is specified), next trader's name
    if (callerPlayer != none && result.options.HasKey(T(TCLOSEST))) {
        newlySelectedTrader = FindClosestTrader(callerPlayer);
    }
    if (newlySelectedTrader == none) {
        newlySelectedTrader = _server.kf.trading.GetTrader(specifiedTraderName);
    }
    //  If nothing is found, but name was specified - there is an error
    if (newlySelectedTrader == none && specifiedTraderName != none)
    {
        callerConsole.Flush()
            .UseColorOnce(_.color.TextFailure).Write(T(TUNKNOWN_TRADERS))
            .WriteLine(specifiedTraderName);
        _.memory.Free(previouslySelectedTrader);
        return;
    }
    //  Select proper trader
    HandleTraderSwap(result, previouslySelectedTrader, newlySelectedTrader);
    _server.kf.trading.SelectTrader(newlySelectedTrader);
    //  Report change
    if (AreTradersSame(previouslySelectedTrader, newlySelectedTrader)) {
        announcer.AnnounceSelectedSameTrader();
    }
    else if (newlySelectedTrader == none) {
        announcer.AnnounceSelectedNoTrader();
    }
    else {
        announcer.AnnounceSelectedTrader(newlySelectedTrader);
    }
    _.memory.Free(previouslySelectedTrader);
    _.memory.Free(newlySelectedTrader);
}

//  Boot players from the old trader iff
//      1. It is different from the new one (otherwise swapping means nothing);
//      2. Option "ignore-players" was not specified.
//      3. New trader was actually closed.
protected function HandleTraderSwap(
    CallData    result,
    ETrader     oldTrader,
    ETrader     newTrader)
{
    local bool closeOldTrader, openNewTrader;
    if (oldTrader == none)                          return;
    if (oldTrader.SameAs(newTrader))                return;

    closeOldTrader  = newTrader == none || !newTrader.IsOpen();
    openNewTrader   = oldTrader.IsOpen();
    if (closeOldTrader)
    {
        if (!result.options.HasKey(T(TIGNORE_DOORS))) {
            oldTrader.Close();
        }
        if (!result.options.HasKey(T(TIGNORE_PLAYERS))) {
            oldTrader.BootPlayers();
        }
    }
    if (openNewTrader && newTrader != none) {
        newTrader.Open();
    }
}

protected function BootFromTraders(CallData result, EPlayer callerPlayer)
{
    local int               i;
    local array<ETrader>    selectedTraders;
    local Text              nextTraderName;
    local ListBuilder       affectedTraderList;

    affectedTraderList = ListBuilder(_.memory.Allocate(class'ListBuilder'));
    selectedTraders = GetTradersArray(result, callerPlayer);
    if (selectedTraders.length <= 0) {
        selectedTraders = _server.kf.trading.GetTraders();
    }
    for (i = 0; i < selectedTraders.length; i += 1)
    {
        nextTraderName = selectedTraders[i].GetName();
        affectedTraderList.Item(nextTraderName);
        selectedTraders[i].BootPlayers();
        _.memory.Free(nextTraderName);
    }
    announcer.AnnounceBootedPlayers(affectedTraderList);
    _.memory.FreeMany(selectedTraders);
    _.memory.Free(affectedTraderList);
}

protected function SetTradersEnabled(
    bool        doEnable,
    CallData    result,
    EPlayer     callerPlayer)
{
    local int               i;
    local array<ETrader>    selectedTraders;
    local Text              nextTraderName;
    local ListBuilder       affectedTraderList;

    affectedTraderList = ListBuilder(_.memory.Allocate(class'ListBuilder'));
    selectedTraders = GetTradersArray(result, callerPlayer);
    for (i = 0; i < selectedTraders.length; i += 1)
    {
        if (doEnable != selectedTraders[i].IsEnabled())
        {
            nextTraderName = selectedTraders[i].GetName();
            affectedTraderList.Item(nextTraderName);
            _.memory.Free(nextTraderName);
        }
        selectedTraders[i].SetEnabled(doEnable);
    }
    if (doEnable) {
        announcer.AnnounceEnabledTraders(affectedTraderList);
    }
    else {
        announcer.AnnounceDisabledTraders(affectedTraderList);
    }
    _.memory.FreeMany(selectedTraders);
    _.memory.Free(affectedTraderList);
}

protected function SetTradersAutoOpen(CallData result, EPlayer callerPlayer)
{
    local int               i;
    local bool              doAutoOpen;
    local array<ETrader>    selectedTraders;
    local Text              nextTraderName;
    local ListBuilder       affectedTraderList;

    affectedTraderList = ListBuilder(_.memory.Allocate(class'ListBuilder'));
    doAutoOpen = result.parameters.GetBool(T(TAUTO_OPEN_QUESTION));
    selectedTraders = GetTradersArray(result, callerPlayer);
    for (i = 0; i < selectedTraders.length; i += 1)
    {
        if (doAutoOpen != selectedTraders[i].IsAutoOpen())
        {
            nextTraderName = selectedTraders[i].GetName();
            affectedTraderList.Item(nextTraderName);
            _.memory.Free(nextTraderName);
        }
        selectedTraders[i].SetAutoOpen(doAutoOpen);
    }
    if (doAutoOpen) {
        announcer.AnnounceAutoOpenTraders(affectedTraderList);
    }
    else {
        announcer.AnnounceDoNotAutoOpenTraders(affectedTraderList);
    }
    _.memory.FreeMany(selectedTraders);
    _.memory.Free(affectedTraderList);
}

//  Reads traders specified for the command (if any).
//  Assumes `result != none`.
protected function array<ETrader> GetTradersArray(
    CallData            result,
    EPlayer             callerPlayer)
{
    local int               i, j;
    local Text              nextTraderName, nextSpecifiedTrader;
    local ArrayList         specifiedTrades;
    local array<ETrader>    resultTraders;
    local array<ETrader>    availableTraders;
    //  Boundary cases: all traders and no traders at all
    availableTraders = _server.kf.trading.GetTraders();
    if (result.options.HasKey(T(TALL))) {
        return availableTraders;
    }
    //  Add closest one, if flag tells us to
    if (result.options.HasKey(T(TCLOSEST)))
    {
        resultTraders =
            InsertTrader(resultTraders, FindClosestTrader(callerPlayer));
    }
    specifiedTrades = result.parameters.GetArrayList(T(TTRADERS));
    if (specifiedTrades == none) {
        return resultTraders;
    }
    //  We iterate over `availableTraders` in the outer loop because:
    //  1. Each `ETrader` from `availableTraders` will be matched only once,
    //      ensuring that result will not contain duplicate instances;
    //  2. `availableTraders.GetName()` creates a new `Text` copy and
    //      `specifiedTrades.GetText()` does not.
    for (i = 0; i < availableTraders.length; i += 1)
    {
        nextTraderName = availableTraders[i].GetName();
        for (j = 0; j < specifiedTrades.GetLength(); j += 1)
        {
            nextSpecifiedTrader = specifiedTrades.GetText(j);
            if (nextTraderName.Compare(nextSpecifiedTrader))
            {
                resultTraders =
                    InsertTrader(resultTraders, availableTraders[i]);
                availableTraders[i] = none;
                specifiedTrades.Remove(j, 1);
                _.memory.Free(nextSpecifiedTrader);
                break;
            }
            _.memory.Free(nextSpecifiedTrader);
        }
        nextTraderName.FreeSelf();
        if (specifiedTrades.GetLength() <= 0) {
            break;
        }
    }
    //  Some of the remaining trader names inside `specifiedTrades` do not
    //  match any actual traders. Report it.
    if (callerPlayer != none && specifiedTrades.GetLength() > 0) {
        ReportUnknowTraders(specifiedTrades);
    }
    _.memory.Free(specifiedTrades);
    _.memory.FreeMany(availableTraders);
    return resultTraders;
}

//  Auxiliary method that adds `newTrader` into existing array of traders
//  if it is still missing.
protected function array<ETrader> InsertTrader(
    /* take */ array<ETrader>   traders,
    /* take */ ETrader          newTrader)
{
    local int i;
    if (newTrader == none) {
        return traders;
    }
    for (i = 0; i < traders.length; i += 1)
    {
        if (traders[i].SameAs(newTrader))
        {
            _.memory.Free(newTrader);
            return traders;
        }
    }
    traders[traders.length] = newTrader;
    return traders;
}

protected function ReportUnknowTraders(ArrayList specifiedTrades)
{
    local int   i;
    local Text  nextTraderName;
    if (specifiedTrades == none) {
        return;
    }
    callerConsole.Flush()
        .UseColorOnce(_.color.TextNegative).Write(T(TUNKNOWN_TRADERS));
    for (i = 0; i < specifiedTrades.GetLength(); i += 1)
    {
        nextTraderName = specifiedTrades.GetText(i);
        callerConsole.Write(nextTraderName);
        _.memory.Free(nextTraderName);
        if (i != specifiedTrades.GetLength() - 1) {
            callerConsole.Write(T(TCOMMA_SPACE));
        }
    }
    callerConsole.Flush();
}

//  Find closest trader to the `target` player
protected function ETrader FindClosestTrader(EPlayer target)
{
    local int               i;
    local float             newDistance, bestDistance;
    local ETrader           bestTrader;
    local array<ETrader>    availableTraders;
    local Vector            targetLocation;
    if (target == none) {
        return none;
    }
    targetLocation = target.GetLocation();
    availableTraders = _server.kf.trading.GetTraders();
    for (i = 0; i < availableTraders.length; i += 1)
    {
        newDistance =
            VSizeSquared(availableTraders[i].GetLocation() - targetLocation);
        if (bestTrader == none || newDistance < bestDistance)
        {
            bestDistance = newDistance;
            _.memory.Free(bestTrader);
            bestTrader = availableTraders[i];
            availableTraders[i] = none;
        }
    }
    _.memory.FreeMany(availableTraders);
    return bestTrader;
}

//  Writes a trader name along with information on whether it's
//  disabled / auto-open
protected function WriteTrader(
    ETrader         traderToWrite,
    bool            isClosestTrader)
{
    local Text traderName;
    if (traderToWrite == none) {
        return;
    }
    callerConsole.Write(T(TQUOTE));
    if (traderToWrite.IsOpen()) {
        callerConsole.UseColor(_.color.TextPositive);
    }
    else {
        callerConsole.UseColor(_.color.TextNegative);
    }
    traderName = traderToWrite.GetName();
    callerConsole.Write(traderName)
        .ResetColor()
        .Write(T(TQUOTE));
    traderName.FreeSelf();
    WriteTraderTags(traderToWrite, isClosestTrader);
}

protected function WriteTraderTags(ETrader traderToWrite, bool isClosest)
{
    local bool hasTagsInFront;
    local bool isAutoOpen, isSelected;
    if (traderToWrite == none) {
        return;
    }
    if (!traderToWrite.IsEnabled())
    {
        callerConsole.Write(T(TDISABLED_FLAG));
        return;
    }
    isAutoOpen = traderToWrite.IsAutoOpen();
    isSelected = traderToWrite.IsSelected();
    if (!isAutoOpen && !isSelected && !isClosest) {
        return;
    }
    callerConsole.Write(T(TSPACE)).Write(T(TPARENTHESIS_OPEN));
    if (isClosest)
    {
        callerConsole.Write(T(TCLOSEST));
        hasTagsInFront = true;
    }
    if (isAutoOpen)
    {
        if (hasTagsInFront) {
            callerConsole.Write(T(TCOMMA_SPACE));
        }
        callerConsole.Write(T(TAUTO_OPEN_FLAG));
        hasTagsInFront = true;
    }
    if (isSelected)
    {
        if (hasTagsInFront) {
            callerConsole.Write(T(TCOMMA_SPACE));
        }
        callerConsole.Write(T(TSELECTED_FLAG));
    }
    callerConsole.Write(T(TPARENTHESIS_CLOSE));
}

defaultproperties
{
    TLIST               = 0
    stringConstants(0)  = "list"
    TOPEN               = 1
    stringConstants(1)  = "open"
    TCLOSE              = 2
    stringConstants(2)  = "close"
    TENABLE             = 3
    stringConstants(3)  = "enable"
    TDISABLE            = 4
    stringConstants(4)  = "disable"
    TAUTO_OPEN          = 5
    stringConstants(5)  = "autoopen"
    TTRADER             = 6
    stringConstants(6)  = "trader"
    TTRADERS            = 7
    stringConstants(7)  = "traders"
    TALL                = 8
    stringConstants(8)  = "all"
    TAUTO_OPEN_QUESTION = 9
    stringConstants(9)  = "autoOpen?"
    TQUOTE              = 10
    stringConstants(10) = "\""
    TAUTO_OPEN_FLAG     = 11
    stringConstants(11) = "auto-open"
    TDISABLED_FLAG      = 12
    stringConstants(12) = " (disabled)"
    TUNKNOWN_TRADERS    = 13
    stringConstants(13) = "Could not find some of the traders: "
    TLIST_TRADERS       = 14
    stringConstants(14) = "List of available traders: "
    TCOMMA_SPACE        = 15
    stringConstants(15) = ", "
    TPARENTHESIS_OPEN   = 16
    stringConstants(16) = "("
    TPARENTHESIS_CLOSE  = 17
    stringConstants(17) = ")"
    TSELECTED_FLAG      = 18
    stringConstants(18) = "selected"
    TSELECT             = 19
    stringConstants(19) = "select"
    TIGNORE_DOORS       = 20
    stringConstants(20) = "ignore-doors"
    TBOOT               = 21
    stringConstants(21) = "boot"
    TTIME               = 22
    stringConstants(22) = "time"
    TTRADER_TIME        = 23
    stringConstants(23) = "traderTime"
    TIGNORE_PLAYERS     = 24
    stringConstants(24) = "ignore-players"
    TPAUSE              = 25
    stringConstants(25) = "pause"
    TUNPAUSE            = 26
    stringConstants(26) = "unpause"
    TCANNOT_PARSE_PARAM = 27
    stringConstants(27) = "Cannot parse parameter: "
    TCLOSEST            = 28
    stringConstants(28) = "closest"
    TSPACE              = 29
    stringConstants(29) = " "
}
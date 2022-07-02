/**
 *      Announcer for `ACommandTrader`.
 *      Copyright 2022 Anton Tarasenko
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
class ACommandTrader_Announcer extends CommandAnnouncer;

var private AnnouncementVariations tradingNoChange;
var private AnnouncementVariations activatedTrading, deactivatedTrading;
var private AnnouncementVariations pausedTime, unpausedTime, changedCountdown;
var private AnnouncementVariations tradersOpened, tradersClosed;
var private AnnouncementVariations selectedNoTrader, selectedSameTrader;
var private AnnouncementVariations selectedTrader, bootedPlayers;
var private AnnouncementVariations enabledTraders, disabledTraders;
var private AnnouncementVariations autoOpenTraders, doNotAutoOpenTraders;

protected function Finalizer()
{
    FreeVariations(tradingNoChange);
    FreeVariations(activatedTrading);
    FreeVariations(deactivatedTrading);
    FreeVariations(pausedTime);
    FreeVariations(unpausedTime);
    FreeVariations(changedCountdown);
    FreeVariations(tradersOpened);
    FreeVariations(tradersClosed);
    FreeVariations(selectedNoTrader);
    FreeVariations(selectedSameTrader);
    FreeVariations(selectedTrader);
    FreeVariations(bootedPlayers);
    FreeVariations(enabledTraders);
    FreeVariations(disabledTraders);
    FreeVariations(autoOpenTraders);
    FreeVariations(doNotAutoOpenTraders);
    super.Finalizer();
}

public final function AnnounceTradingNoChange()
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!tradingNoChange.initialized)
    {
        tradingNoChange.initialized = true;
        tradingNoChange.toSelfReport = _.text.MakeTemplate_S(
            "There was {$TextNegative no change} in trading time status");
    }
    templates = MakeArray(tradingNoChange);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset();
    }
    MakeAnnouncement(tradingNoChange);
}

public final function AnnounceActivatedTrading()
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!activatedTrading.initialized)
    {
        activatedTrading.initialized = true;
        activatedTrading.toSelfReport = _.text.MakeTemplate_S(
            "Trader time {$TextPositive started}");
        activatedTrading.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextPositive started} trader time");
    }
    templates = MakeArray(activatedTrading);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset();
    }
    MakeAnnouncement(activatedTrading);
}

public final function AnnounceDeactivatedTrading()
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!deactivatedTrading.initialized)
    {
        deactivatedTrading.initialized = true;
        deactivatedTrading.toSelfReport = _.text.MakeTemplate_S(
            "Trader time {$TextNegative ended}");
        deactivatedTrading.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextNegative ended} trader time");
    }
    templates = MakeArray(pausedTime);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset();
    }
    MakeAnnouncement(deactivatedTrading);
}

public final function AnnouncePausedTime()
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!pausedTime.initialized)
    {
        pausedTime.initialized = true;
        pausedTime.toSelfReport = _.text.MakeTemplate_S(
            "Trader time {$TextNeutral paused}");
        pausedTime.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextNeutral paused} trader time");
    }
    templates = MakeArray(pausedTime);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset();
    }
    MakeAnnouncement(pausedTime);
}

public final function AnnounceUnpausedTime()
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!unpausedTime.initialized)
    {
        unpausedTime.initialized = true;
        unpausedTime.toSelfReport = _.text.MakeTemplate_S(
            "Trader time {$TextNeutral unpaused}");
        unpausedTime.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextNeutral unpaused} trader time");
    }
    templates = MakeArray(unpausedTime);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset();
    }
    MakeAnnouncement(unpausedTime);
}

public final function AnnounceChangedCountdown(int userTimerValue)
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!changedCountdown.initialized)
    {
        changedCountdown.initialized = true;
        changedCountdown.toSelfReport = _.text.MakeTemplate_S(
            "Trader time {$TextNeutral changed} to %1");
        changedCountdown.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextNeutral changed} trader time to %1");
    }
    templates = MakeArray(changedCountdown);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().ArgInt(userTimerValue);
    }
    MakeAnnouncement(changedCountdown);
}

public final function AnnounceTradersOpened(ListBuilder traderList)
{
    local int                   i;
    local MutableText           traderListAsText;
    local array<TextTemplate>   templates;

    if (!tradersOpened.initialized)
    {
        tradersOpened.initialized = true;
        tradersOpened.toSelfReport = _.text.MakeTemplate_S(
            "{$TextPositive Opened} following traders: %1");
        tradersOpened.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextPositive opened} following traders: %1");
    }
    if (traderList.IsEmpty()) {
        return;
    }
    traderListAsText = traderList.GetMutable();
    templates = MakeArray(tradersOpened);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().Arg(traderListAsText);
    }
    MakeAnnouncement(tradersOpened);
    _.memory.Free(traderListAsText);
}

public final function AnnounceTradersClosed(ListBuilder traderList)
{
    local int                   i;
    local MutableText           traderListAsText;
    local array<TextTemplate>   templates;

    if (!tradersClosed.initialized)
    {
        tradersClosed.initialized = true;
        tradersClosed.toSelfReport = _.text.MakeTemplate_S(
            "{$TextNegative Closed} following traders: %1");
        tradersClosed.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextNegative closed} following traders: %1");
    }
    if (traderList.IsEmpty()) {
        return;
    }
    traderListAsText = traderList.GetMutable();
    templates = MakeArray(tradersClosed);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().Arg(traderListAsText);
    }
    MakeAnnouncement(tradersClosed);
    _.memory.Free(traderListAsText);
}

public final function AnnounceSelectedNoTrader()
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!selectedNoTrader.initialized)
    {
        selectedNoTrader.initialized = true;
        selectedNoTrader.toSelfReport = _.text.MakeTemplate_S(
            "All traders were {$TextNegative deselected}");
        selectedNoTrader.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextNegative deselected} all traders");
    }
    templates = MakeArray(selectedNoTrader);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset();
    }
    MakeAnnouncement(selectedNoTrader);
}

public final function AnnounceSelectedSameTrader()
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!selectedSameTrader.initialized)
    {
        selectedSameTrader.initialized = true;
        selectedSameTrader.toSelfReport = _.text.MakeTemplate_S(
            "{$TestNeutral No changes} made as a result of"
            @ "{$TextEmphasis select} command");
    }
    templates = MakeArray(selectedSameTrader);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset();
    }
    MakeAnnouncement(selectedSameTrader);
}

public final function AnnounceSelectedTrader(ETrader trader)
{
    local int                   i;
    local Text                  traderName;
    local array<TextTemplate>   templates;

    if (!selectedTrader.initialized)
    {
        selectedTrader.initialized = true;
        selectedTrader.toSelfReport = _.text.MakeTemplate_S(
            "{$TextNeutral Selected} trader \"%1\"");
        selectedTrader.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextNeutral selected} trader \"%1\"");
    }
    traderName = trader.GetName();
    templates = MakeArray(selectedTrader);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().Arg(traderName);
    }
    MakeAnnouncement(selectedTrader);
    _.memory.Free(traderName);
}

public final function AnnounceBootedPlayers(ListBuilder traderList)
{
    local int                   i;
    local MutableText           traderListAsText;
    local array<TextTemplate>   templates;

    if (!bootedPlayers.initialized)
    {
        bootedPlayers.initialized = true;
        bootedPlayers.toSelfReport = _.text.MakeTemplate_S(
            "{$TextNegative Booted} players from following traders: %1");
        bootedPlayers.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextNegative booted} players from following"
            @ "traders: %1");
    }
    if (traderList.IsEmpty()) {
        return;
    }
    traderListAsText = traderList.GetMutable();
    templates = MakeArray(bootedPlayers);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().Arg(traderListAsText);
    }
    MakeAnnouncement(bootedPlayers);
    _.memory.Free(traderListAsText);
}

public final function AnnounceEnabledTraders(ListBuilder traderList)
{
    local int                   i;
    local MutableText           traderListAsText;
    local array<TextTemplate>   templates;

    if (!enabledTraders.initialized)
    {
        enabledTraders.initialized = true;
        enabledTraders.toSelfReport = _.text.MakeTemplate_S(
            "{$TextPositive Enabled} following traders: %1");
        enabledTraders.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextPositive enabled} following traders: %1");
    }
    if (traderList.IsEmpty()) {
        return;
    }
    traderListAsText = traderList.GetMutable();
    templates = MakeArray(enabledTraders);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().Arg(traderListAsText);
    }
    MakeAnnouncement(enabledTraders);
    _.memory.Free(traderListAsText);
}

public final function AnnounceDisabledTraders(ListBuilder traderList)
{
    local int                   i;
    local MutableText           traderListAsText;
    local array<TextTemplate>   templates;

    if (!disabledTraders.initialized)
    {
        disabledTraders.initialized = true;
        disabledTraders.toSelfReport = _.text.MakeTemplate_S(
            "{$TextNegative Disabled} following traders: %1");
        disabledTraders.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextNegative disabled} following traders: %1");
    }
    if (traderList.IsEmpty()) {
        return;
    }
    traderListAsText = traderList.GetMutable();
    templates = MakeArray(disabledTraders);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().Arg(traderListAsText);
    }
    MakeAnnouncement(disabledTraders);
    _.memory.Free(traderListAsText);
}

public final function AnnounceAutoOpenTraders(ListBuilder traderList)
{
    local int                   i;
    local MutableText           traderListAsText;
    local array<TextTemplate>   templates;

    if (!autoOpenTraders.initialized)
    {
        autoOpenTraders.initialized = true;
        autoOpenTraders.toSelfReport = _.text.MakeTemplate_S(
            "Following traders will be {$TextPositive auto-opened}: %1");
        autoOpenTraders.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% made following traders {$TextPositive automatically"
            @ "openable}: %1");
    }
    if (traderList.IsEmpty()) {
        return;
    }
    traderListAsText = traderList.GetMutable();
    templates = MakeArray(autoOpenTraders);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().Arg(traderListAsText);
    }
    MakeAnnouncement(autoOpenTraders);
    _.memory.Free(traderListAsText);
}

public final function AnnounceDoNotAutoOpenTraders(ListBuilder traderList)
{
    local int                   i;
    local MutableText           traderListAsText;
    local array<TextTemplate>   templates;

    if (!doNotAutoOpenTraders.initialized)
    {
        doNotAutoOpenTraders.initialized = true;
        doNotAutoOpenTraders.toSelfReport = _.text.MakeTemplate_S(
            "Following traders will {$TextNegative no longer} be auto-opened:"
            @ "%1");
        doNotAutoOpenTraders.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% made following traders {$TextNegative no longer}"
            @ "automatically openable: %1");
    }
    if (traderList.IsEmpty()) {
        return;
    }
    traderListAsText = traderList.GetMutable();
    templates = MakeArray(doNotAutoOpenTraders);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().Arg(traderListAsText);
    }
    MakeAnnouncement(doNotAutoOpenTraders);
    _.memory.Free(traderListAsText);
}

defaultproperties
{
}
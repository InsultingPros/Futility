/**
 *  Command for making player immortal.
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
class ACommandGod extends Command;

struct GodStatus
{
    //  Player to whom we grant godhood
    var EPlayer target;
    //  Is `target` only a demigod (can get damaged, but not die)?
    var bool    demigod;
    //  Should `target` be unaffected by attacks momentum?
    var bool    unmovable;
};

var private bool                connectedToSignal;
var private array<GodStatus>    godhoodList;

var private ACommandGod_Announcer announcer;

var private const int TDAMAGE, TMOMENTUM;

protected function Finalizer()
{
    connectedToSignal = false;
    _server.kf.health.OnDamage(self).Disconnect();
    _.memory.Free(announcer);
    super.Finalizer();
}

protected function BuildData(CommandDataBuilder builder)
{
    builder.Name(P("god")).Group(P("gameplay"))
        .Summary(P("Command for making player immortal."));
    builder.RequireTarget()
        .Describe(P("Gives targeted players god status, making them"
            @ "invincible."));
    builder.SubCommand(P("list"))
        .Describe(P("Reports godhood status of targeted players."));
    builder.SubCommand(P("strip"))
        .Describe(P("Strips targeted players from the godhood status."));
    builder.Option(P("demi"))
        .Describe(P("This flag makes targeted players \"demigods\" instead -"
            @ "they still cannot die, but they can take any non-lethal"
            @ "damage."));
    builder.Option(P("unmovable"))
        .Describe(P("This flag also prevents targeted players from being"
            @ "affected by the momentum trasnferred from damaging attacks."));
    announcer = ACommandGod_Announcer(
        _.memory.Allocate(class'ACommandGod_Announcer'));
}

protected function ExecutedFor(
    EPlayer     target,
    CallData    arguments,
    EPlayer     instigator)
{
    local GodStatus newGodStatus;

    announcer.Setup(target, instigator, othersConsole);
    if (arguments.subCommandName.IsEmpty())
    {
        newGodStatus.target = target;
        newGodStatus.demigod = arguments.options.HasKey(P("demi"));
        newGodStatus.unmovable = arguments.options.HasKey(P("unmovable"));
        MakeGod(target, newGodStatus);
    }
    else if (arguments.subCommandName.Compare(P("list"))) {
        announcer.AnnounceGodStatus(BorrowGodStatus(target));
    }
    else if (arguments.subCommandName.Compare(P("strip"))) {
        RemoveGod(target);
    }
}

private function ProtectDivines(
    EPawn       target,
    EPawn       instigator,
    HashTable   damageData)
{
    local int       damage;
    local EPlayer   targetedPlayer;
    local GodStatus targetDivinity;

    targetedPlayer = target.GetPlayer();
    targetDivinity = BorrowGodStatus(targetedPlayer);
    _.memory.Free(targetedPlayer);
    if (targetDivinity.target == none) {
        return;
    }
    if (targetDivinity.unmovable) {
        damageData.SetVector(T(TMOMENTUM), Vect(0.0f, 0.0f, 0.0f));
    }
    if (targetDivinity.demiGod)
    {
        damage = damageData.GetInt(T(TDAMAGE));
        damage = Min(damage, target.GetHealth() - 1);
        damageData.SetInt(T(TDAMAGE), damage);
    }
    else {
        damageData.SetInt(T(TDAMAGE), 0);
    }
}

private final function MakeGod(
    EPlayer     target,
    GodStatus   newGodStatus)
{
    local int       godIndex;
    local bool      wasGod;
    local GodStatus oldGodStatus;

    if (target == none) {
        return;
    }
    for (godIndex = 0; godIndex < godhoodList.length; godIndex += 1)
    {
        if (target.SameAs(godhoodList[godIndex].target))
        {
            wasGod = true;
            oldGodStatus = godhoodList[godIndex];
            break;
        }
    }
    if (wasGod)
    {
        if (    newGodStatus.demiGod == oldGodStatus.demiGod
            &&  newGodStatus.unmovable == oldGodStatus.unmovable)
        {
            announcer.AnnounceSameGod(newGodStatus);
        }
        else
        {
            announcer.AnnounceChangedGod(oldGodStatus, newGodStatus);
            godhoodList[godIndex].target.FreeSelf();
            newGodStatus.target.NewRef();
            godhoodList[godIndex] = newGodStatus;
        }
    }
    else {
        announcer.AnnounceNewGod(newGodStatus);
        newGodStatus.target.NewRef();
        godhoodList[godhoodList.length] = newGodStatus;
    }
    UpdateHealthSignalConnection();
}

private final function RemoveGod(EPlayer target)
{
    local int i;

    if (target == none) {
        return;
    }
    for (i = 0; i < godhoodList.length; i += 1)
    {
        if (target.SameAs(godhoodList[i].target))
        {
            announcer.AnnounceRemoveGod(godhoodList[i]);
            godhoodList[i].target.FreeSelf();
            godhoodList.Remove(i, 1);
            UpdateHealthSignalConnection();
            return;
        }
    }
    announcer.AnnounceWasNotGod();
}

private final function GodStatus BorrowGodStatus(EPlayer target)
{
    local int       i;
    local GodStatus emptyStatus;

    if (target == none) {
        return emptyStatus;
    }
    for (i = 0; i < godhoodList.length; i += 1)
    {
        if (target.SameAs(godhoodList[i].target)) {
            return godhoodList[i];
        }
    }
    return emptyStatus;
}

private final function UpdateHealthSignalConnection()
{
    if (connectedToSignal && godhoodList.length <= 0)
    {
        _server.kf.health.OnDamage(self).Disconnect();
        connectedToSignal = false;
    }
    if (!connectedToSignal && godhoodList.length > 0)
    {
        connectedToSignal = true;
        _server.kf.health.OnDamage(self).connect = ProtectDivines;
    }
}

defaultproperties
{
    TDAMAGE             = 0
    stringConstants(0) = "damage"
    TMOMENTUM           = 1
    stringConstants(1) = "momentum"
}
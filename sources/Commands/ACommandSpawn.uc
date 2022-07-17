/**
 *  Command for spawning new entities into the world.
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
class ACommandSpawn extends Command;

//  TODO: use spawned name for errors output?
var private ACommandSpawn_Announcer announcer;

protected function Finalizer()
{
    _.memory.Free(announcer);
    super.Finalizer();
}

protected function BuildData(CommandDataBuilder builder)
{
    builder.Name(P("spawn")).Group(P("debug"))
        .Summary(P("Spawns new entity on the map."));
    builder.ParamText(P("template"))
        .Describe(P("Spawns new entity based on the given template at the point"
            @ "player is currently looking at."));
    builder.SubCommand(P("at"))
        .ParamText(P("template"))
        .ParamNumber(P("x"))
        .ParamNumber(P("y"))
        .ParamNumber(P("z"))
        .Describe(P("Spawns new entity based on the given template at"
            @ "the point, given by the coordinates"));
    announcer = ACommandSpawn_Announcer(
        _.memory.Allocate(class'ACommandSpawn_Announcer'));
}

protected function Executed(
    CallData    arguments,
    EPlayer     instigator)
{
    local Text      givenTemplate, template;
    local Vector    spawnLocation;

    announcer.Setup(none, instigator, othersConsole);
    givenTemplate = arguments.parameters.GetText(P("template"));
    if (givenTemplate.StartsWithS("$")) {
        template = _.alias.ResolveEntity(givenTemplate, true);
    }
    else {
        template = givenTemplate.Copy();
    }
    _.memory.Free(givenTemplate);
    if (arguments.subCommandName.IsEmpty()) {
        SpawnInInstigatorSight(instigator, template);
    }
    else if (arguments.subCommandName.Compare(P("at"), SCASE_INSENSITIVE))
    {
        spawnLocation.x = arguments.parameters.GetFloat(P("x"));
        spawnLocation.y = arguments.parameters.GetFloat(P("y"));
        spawnLocation.z = arguments.parameters.GetFloat(P("z"));
        SpawnAt(instigator, template, spawnLocation);
    }
    _.memory.Free(template);
}

private final function SpawnAt(
    EPlayer     instigator,
    BaseText    template,
    Vector      spawnLocation)
{
    local EPlaceable result;

    result = _server.kf.world.Spawn(template, spawnLocation);
    if (result != none) {
        announcer.AnnounceSpawned(template);
    }
    else {
        announcer.AnnounceSpawningFailed(template);
    }
    _.memory.Free(result);
}

private final function SpawnInInstigatorSight(
    EPlayer     instigator,
    BaseText    template)
{
    local EPlaceable        result;
    local Vector            spawnLocation;
    local TracingIterator   iter;

    iter = _server.kf.world.TracePlayerSight(instigator);
    if (iter.LeaveOnlyVisible().HasFinished())
    {
        announcer.AnnounceFailedTrace();
        return;
    }
    spawnLocation = iter.GetHitLocation();
    result = _server.kf.world.Spawn(template, spawnLocation);
    //  Shift position back a little and try again;
    //  this should fix a ton of spawning failures
    if (result == none)
    {
        spawnLocation = spawnLocation +
            Normal(iter.GetTracingStart() - spawnLocation) * 100;
        result = _server.kf.world.Spawn(template, spawnLocation);
    }
    if (result != none) {
        announcer.AnnounceSpawned(template);
    }
    else {
        announcer.AnnounceSpawningFailed(template);
    }
    _.memory.Free(result);
    _.memory.Free(iter);
}

defaultproperties
{
}
/**
 *  This is the Futility feature, whose main purpose is to register commands
 *  from its package.
 *      Copyright 2021-2022 Anton Tarasenko
 *------------------------------------------------------------------------------
 * This file is part of Futility.
 *
 * Futility is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License, or
 * (at your option) any later version.
 *
 * Futility is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Futility.  If not, see <https://www.gnu.org/licenses/>.
 */
class Futility_Feature extends Feature;

var private array< class<Command> > allCommandClasses;

var private LoggerAPI.Definition errNoCommandsFeature;

protected function OnEnabled()
{
    local int               i;
    local Commands_Feature  commandsFeature;
    commandsFeature =
        Commands_Feature(class'Commands_Feature'.static.GetEnabledInstance());
    if (commandsFeature == none)
    {
        _.logger.Auto(errNoCommandsFeature);
        return;
    }
    for (i = 0; i < allCommandClasses.length; i += 1) {
        commandsFeature.RegisterCommand(allCommandClasses[i]);
    }
    _.environment.OnFeatureEnabled(self).connect = RegisterAllCommandClasses;
}

protected function OnDisabled()
{
    local int               i;
    local Commands_Feature  commandsFeature;
    _.environment.OnFeatureEnabled(self).Disconnect();
    commandsFeature =
        Commands_Feature(class'Commands_Feature'.static.GetEnabledInstance());
    if (commandsFeature == none) {
        return;
    }
    for (i = 0; i < allCommandClasses.length; i += 1) {
        commandsFeature.RegisterCommand(allCommandClasses[i]);
    }
}

private final function RegisterAllCommandClasses(Feature enabledFeature)
{
    local int               i;
    local Commands_Feature  commandsFeature;
    commandsFeature = Commands_Feature(enabledFeature);
    if (commandsFeature == none) {
        return;
    }
    for (i = 0; i < allCommandClasses.length; i += 1) {
        commandsFeature.RegisterCommand(allCommandClasses[i]);
    }
}

defaultproperties
{
    configClass = class'Futility'
    allCommandClasses(0) = class'ACommandDosh'
    allCommandClasses(1) = class'ACommandNick'
    allCommandClasses(2) = class'ACommandTrader'
    allCommandClasses(3) = class'ACommandDB'
    allCommandClasses(4) = class'ACommandInventory'
    allCommandClasses(5) = class'ACommandFeature'
    allCommandClasses(6) = class'ACommandGod'
    allCommandClasses(7) = class'ACommandSpawn'
    allCommandClasses(8) = class'ACommandUserData'
    errNoCommandsFeature = (l=LOG_Error,m="`Commands_Feature` is not detected, \"Futility\" will not be able to provide its functionality.")
}
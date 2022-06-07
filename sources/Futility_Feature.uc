/**
 *  This is the Futility feature, whose main purpose is to register commands
 *  from its package.
 *      Copyright 2021 Anton Tarasenko
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

var LoggerAPI.Definition errNoCommandsFeature;

protected function OnEnabled()
{
    local Commands_Feature commandsFeature;
    commandsFeature =
        Commands_Feature(class'Commands_Feature'.static.GetInstance());
    if (commandsFeature == none)
    {
        _.logger.Auto(errNoCommandsFeature);
        return;
    }
    commandsFeature.RegisterCommand(class'ACommandDosh');
    commandsFeature.RegisterCommand(class'ACommandNick');
    commandsFeature.RegisterCommand(class'ACommandTrader');
    commandsFeature.RegisterCommand(class'ACommandDB');
    commandsFeature.RegisterCommand(class'ACommandInventory');
}

protected function OnDisabled()
{
    local Commands_Feature commandsFeature;
    commandsFeature =
        Commands_Feature(class'Commands_Feature'.static.GetInstance());
    if (commandsFeature != none)
    {
        commandsFeature.RemoveCommand(class'ACommandDosh');
        commandsFeature.RemoveCommand(class'ACommandNick');
        commandsFeature.RemoveCommand(class'ACommandTrader');
        commandsFeature.RemoveCommand(class'ACommandDB');
        commandsFeature.RemoveCommand(class'ACommandInventory');
    }
}

defaultproperties
{
    configClass = class'Futility'
    errNoCommandsFeature = (l=LOG_Error,m="`Commands_Feature` is not detected, \"Futility\" will not be able to provide its functionality.")
}
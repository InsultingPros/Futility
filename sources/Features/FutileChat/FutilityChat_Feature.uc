/**
 *  This feature allows to configure color of text chat messages.
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
class FutilityChat_Feature extends Feature
    dependson(FutilityChat);

//  How to color text chat messages?
//      1. `CCS_DoNothing` - do not change color in any way;
//      2. `CCS_TeamColorForced` - force players' team colors for
//          their messages;
//      3. `CCS_ConfigColorForced` - force `configuredColor` value for
//          players' messages;
//      4. `CCS_TeamColorCustom` - use players' team colors for
//          their messages by default, but allow to change color with formatted
//          tags (e.g. "Stop right there, {$crimson criminal} scum!");
//      5. `CCS_ConfigColorCustom` - use `configuredColor` value for
//          messages by default, but allow to change color with formatted
//          tags (e.g. "Stop right there, {$crimson criminal} scum!");
//  Default is `CCS_DoNothing`, corresponding to vanilla behaviour.
var private /*config*/ FutilityChat.ChatColorSetting    colorSetting;
//  Color that will be used if either of `CCS_ConfigColorForced` or
//  `CCS_ConfigColorCustom` options were used in `colorSetting`.
//  Default value is white: (R=255,G=255,B=255,A=255),
//  has no vanilla equivalent.
var private /*config*/ Color                            configuredColor;   
//      Allows to modify team color's value for the chat messages
//  (if either of `CCS_TeamColorForced` or `CCS_TeamColorCustom` options
//  were used) to be lighter or darker.
//      This value is clamped between -1 and 1.
//          * `0` means using the same color;
//          * range (0; 1) - gives you lighter colors (`1` being white);
//          * range (-1; 0) - gives you darker colors (`-1` being black);
//  Default value is `0.6`, has no vanilla equivalent.
var private /*config*/ float                            teamColorModifier;

//  Keep track of whether we connected to necessary signals, so that we can
//  connect to them or disconnect from them once setting get updated
var private bool connectedToSignal;

protected function OnDisabled()
{
    if (connectedToSignal)
    {
        connectedToSignal = false;
        _.chat.OnMessage(self).Disconnect();
    }
}

protected function SwapConfig(FeatureConfig config)
{
    local bool          configRequiresSignal;
    local FutilityChat  newConfig;
    newConfig = FutilityChat(config);
    if (newConfig == none) {
        return;
    }
    colorSetting            = newConfig.colorSetting;
    configuredColor         = newConfig.configuredColor;
    teamColorModifier       = newConfig.teamColorModifier;
    configRequiresSignal    = (colorSetting != CCS_DoNothing);
    //  Enable or disable censoring if `IsAnyCensoringEnabled()`'s response
    //  has changed.
    if (!connectedToSignal && configRequiresSignal)
    {
        connectedToSignal = true;
        _.chat.OnMessage(self).connect = ReformatChatMessage;
    }
    if (connectedToSignal && !configRequiresSignal)
    {
        connectedToSignal = false;
        _.chat.OnMessage(self).Disconnect();
    }
}

private function bool ReformatChatMessage(
    EPlayer     sender,
    MutableText message,
    bool        teamMessage)
{
    local Text                  messageCopy;
    local BaseText.Formatting   defaultFormatting;
    if (sender == none)                 return true;
    if (message == none)                return true;
    if (colorSetting == CCS_DoNothing)  return true;

    defaultFormatting.isColored = true;
    if (    colorSetting == CCS_TeamColorForced
        ||  colorSetting == CCS_TeamColorCustom)
    {
        defaultFormatting.color = ModColor(sender.GetTeamColor());
    }
    else {
        defaultFormatting.color = configuredColor;
    }
    if (message.StartsWith(P("|"))) {
        message.Remove(0, 1);
    }
    else if (   colorSetting != CCS_TeamColorForced
            &&  colorSetting != CCS_ConfigColorForced)
    {
        messageCopy = message.Copy();
        class'FormattingStringParser'.static
            .ParseFormatted(messageCopy, message.Clear());
        _.memory.Free(messageCopy);
    }
    message.ChangeDefaultFormatting(defaultFormatting);
    return true;
}

private function Color ModColor(Color inputColor)
{
    local Color mixColor;
    local Color outputColor;
    local float clampedModifier;
    if (Abs(teamColorModifier) < 0.001) {
        return inputColor;
    }
    clampedModifier = FClamp(teamColorModifier, -1.0, 1.0);
    if (clampedModifier > 0) {
        mixColor = _.color.White;
    }
    else
    {
        mixColor = _.color.Black;
        clampedModifier *= -1.0;
    }
    outputColor.R = Lerp(clampedModifier, inputColor.R, mixColor.R);
    outputColor.G = Lerp(clampedModifier, inputColor.G, mixColor.G);
    outputColor.B = Lerp(clampedModifier, inputColor.B, mixColor.B);
    outputColor.A = inputColor.A;
    return outputColor;
}

defaultproperties
{
    configClass = class'FutilityChat'
}
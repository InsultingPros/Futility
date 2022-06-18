/**
 *  Command for changing nickname of the player.
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
class ACommandNick extends Command;

protected function BuildData(CommandDataBuilder builder)
{
    builder.Name(P("nick")).Summary(P("Changes nickname."));
    builder.RequireTarget();
    builder.ParamText(P("nick"))
        .Describe(P("Changes nickname of targeted players to <nick>."));
    builder.Option(P("plain"))
        .Describe(P("Take nickname exactly as typed, without attempting to"
            @ "treat it like formatted string."));
    builder.Option(P("fix"), P("F"))
        .Describe(P("In case of a nickname with erroroneous formatting or"
            @ "invalid default color (specified with `--color`),"
            @ "try to fix/ignore it instead of simply rejecting it."));
    builder.Option(P("color"))
        .Describe(P("Color to use for the nickname. In case nickname is already"
            @ "colored, this flag will only affects uncolored parts."))
        .ParamText(P("default_color"));
}

protected function ExecutedFor(
    EPlayer     player,
    CallData    result,
    EPlayer     callerPlayer)
{
    local bool          foundErrors, selfChange;
    local Text          givenName, oldName, callerName;
    local MutableText   newName;
    local array<FormattingErrorsReport.FormattedStringError> errors;
    oldName     = player.GetName();
    givenName   = result.parameters.GetText(P("nick"));
    callerName  = callerPlayer.GetName();
    selfChange  = callerPlayer.SameAs(player);
    if (result.options.HasKey(P("plain")))
    {
        player.SetName(givenName);
        AnnounceNicknameChange(callerName, oldName, givenName, selfChange);
        _.memory.Free(oldName);
        _.memory.Free(callerName);
        return;
    }
    newName = _.text.Empty();
    errors = class'FormattingStringParser'.static
        .ParseFormatted(givenName, newName, true);
    if (result.options.HasKey(P("color")))
    {
        foundErrors = !TryChangeDefaultColor(
            newName, result.options.GetTextBy(P("/color/default_color")));
    }
    foundErrors = foundErrors || (errors.length > 0);
    if (!foundErrors || result.options.HasKey(P("fix")))
    {
        player.SetName(newName);
        AnnounceNicknameChange(callerName, oldName, newName, selfChange);
    }
    class'FormattingReportTool'.static.Report(callerConsole, errors);
    class'FormattingReportTool'.static.FreeErrors(errors);
    _.memory.Free(newName);
    _.memory.Free(oldName);
    _.memory.Free(callerName);
}

protected function bool TryChangeDefaultColor(
    MutableText newName,
    BaseText    specifiedColor)
{
    local Color defaultColor;
    if (newName == none)        return false;
    if (specifiedColor == none) return false;

    if (_.color.Parse(specifiedColor, defaultColor))
    {
        newName.ChangeDefaultFormatting(
                _.text.FormattingFromColor(defaultColor));
        return true;
    }
    callerConsole
        .Write(F("Specified {$TextFailure invalid} color: "))
        .WriteLine(specifiedColor);
    return false;
}

protected function AnnounceNicknameChange(
    BaseText    callerName,
    BaseText    oldName,
    BaseText    newName,
    bool        selfChange)
{
    if (selfChange)
    {
        callerConsole
            .Write(F("Your nickname was {$TextPositive changed} to "))
            .WriteLine(newName);
        othersConsole
            .Write(callerName)
            .Write(F(" {$TextEmphasis changed} thier own nickname to "))
            .WriteLine(newName);
        return;
    }
    callerConsole
        .Write(P("Nickname for player ")).Write(oldName)
        .Write(F(" was {$TextPositive changed} to ")).WriteLine(newName);
    targetConsole
        .Write(F("Your nickname was {$TextEmphasis changed} to "))
        .Write(newName)
        .Write(P(" by "))
        .WriteLine(callerName);
    othersConsole
        .Write(callerName)
        .Write(F(" {$TextEmphasis changed} nickname for player "))
        .Write(oldName)
        .Write(P(" to "))
        .WriteLine(newName);
}

defaultproperties
{
}
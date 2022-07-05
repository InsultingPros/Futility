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

var private bool        foundErrors;
var private MutableText newName;

var private ACommandNick_Announcer announcer;

protected function Finalizer()
{
    _.memory.Free(announcer);
    _.memory.Free(newName);
    newName = none;
    super.Finalizer();
}

protected function BuildData(CommandDataBuilder builder)
{
    builder.Name(P("nick")).Group(P("gameplay"))
        .Summary(P("Changes nickname."));
    builder.RequireTarget();
    builder.ParamRemainder(P("nick"))
        .Describe(P("Changes nickname of targeted players to <nick>."));
    builder.Option(P("plain"))
        .Describe(P("Take nickname exactly as typed, without attempting to"
            @ "treat it like formatted string."));
    builder.Option(P("fix"), P("f"))
        .Describe(P("In case of a nickname with erroroneous formatting or"
            @ "invalid default color (specified with `--color`),"
            @ "try to fix/ignore it instead of simply rejecting it."));
    builder.Option(P("color"))
        .Describe(P("Color to use for the nickname. In case nickname is already"
            @ "colored, this flag will only affects uncolored parts."))
        .ParamText(P("default_color"));
    announcer = ACommandNick_Announcer(
        _.memory.Allocate(class'ACommandNick_Announcer'));
}

protected function Executed(
    CallData    arguments,
    EPlayer     callerPlayer)
{
    local Text                                                  givenName;
    local array<FormattingErrorsReport.FormattedStringError>    errors;

    givenName = arguments.parameters.GetText(P("nick"));
    //      `newName`'s reference persists between different command calls and
    //  only deallocated when we need this variable for the next execution.
    //      "Leaking" a single `Text` like that is insignificant.
    _.memory.Free(newName);
    newName = _.text.Empty();
    if (arguments.options.HasKey(P("plain"))) {
        newName = givenName.MutableCopy();
    }
    else
    {
        errors = class'FormattingStringParser'.static
            .ParseFormatted(givenName, newName, true);
    }
    foundErrors = false;
    if (arguments.options.HasKey(P("color")))
    {
        foundErrors = !TryChangeDefaultColor(
            arguments.options.GetTextBy(P("/color/default_color")));
    }
    foundErrors = foundErrors || (errors.length > 0);
    class'FormattingReportTool'.static.Report(callerConsole, errors);
    class'FormattingReportTool'.static.FreeErrors(errors);
}

protected function ExecutedFor(
    EPlayer     target,
    CallData    arguments,
    EPlayer     instigator)
{
    local Text alteredVersion;

    if (!foundErrors || arguments.options.HasKey(P("fix")))
    {
        announcer.Setup(target, instigator, othersConsole);
        target.SetName(newName);
        alteredVersion = target.GetName();
        if (newName.Compare(alteredVersion, SCASE_SENSITIVE, SFORM_SENSITIVE)) {
            announcer.AnnounceChangedNickname(newName);
        }
        else {
            announcer.AnnounceChangedAlteredNickname(newName, alteredVersion);
        }
        _.memory.Free(alteredVersion);
    }
}

protected function bool TryChangeDefaultColor(BaseText specifiedColor)
{
    local Color defaultColor;

    if (newName == none)        return false;
    if (specifiedColor == none) return false;

    if (_.color.Parse(specifiedColor, defaultColor))
    {
        newName.ChangeDefaultColor(defaultColor);
        return true;
    }
    callerConsole
        .Write(F("Specified {$TextFailure invalid} color: "))
        .WriteLine(specifiedColor);
    return false;
}

defaultproperties
{
}
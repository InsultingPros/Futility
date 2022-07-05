/**
 *  Command for changing amount of money players have.
 *      Copyright 2021 - 2022 Anton Tarasenko
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
class ACommandDosh extends Command;

var private ACommandDosh_Announcer announcer;

protected function Finalizer()
{
    _.memory.Free(announcer);
    super.Finalizer();
}

protected function BuildData(CommandDataBuilder builder)
{
    builder.Name(P("dosh")).Group(P("gameplay"))
        .Summary(P("Changes amount of money."));
    builder.RequireTarget();
    builder.ParamInteger(P("amount"))
        .Describe(P("Gives (or takes if negative) players a specified <amount>"
            @ "of money."));
    builder.SubCommand(P("set"))
        .ParamInteger(P("amount"))
        .Describe(P("Sets player's money to a specified <amount>."));
    builder.Option(P("min"))
        .ParamInteger(P("minValue"))
        .Describe(F("Players will retain at least this amount of dosh after"
            @ "the command's execution. In case of conflict, overrides"
            @ "'{$TextEmphasis --max}' option. `0` is assumed by default."));
    builder.Option(P("max"), P("M"))
        .ParamInteger(P("maxValue"))
        .Describe(F("Players will have at most this amount of dosh after"
            @ "the command's execution. In case of conflict, it is overridden"
            @ "by '{$TextEmphasis --min}' option."));
    announcer = ACommandDosh_Announcer(
        _.memory.Allocate(class'ACommandDosh_Announcer'));
}

protected function ExecutedFor(
    EPlayer     target,
    CallData    arguments,
    EPlayer     instigator)
{
    local int oldAmount, newAmount;
    local int amount, minValue, maxValue;

    //  Find min and max value boundaries
    minValue = arguments.options.GetIntBy(P("/min/minValue"), 0);
    maxValue = arguments.options.GetIntBy(P("/max/maxValue"), MaxInt);
    if (minValue > maxValue) {
        maxValue = minValue;
    }
    //  Change dosh
    oldAmount = target.GetDosh();
    amount = arguments.parameters.GetInt(P("amount"));
    if (arguments.subCommandName.IsEmpty()) {
        newAmount = oldAmount + amount;
    }
    else {
        //  This has to be "dosh set"
        newAmount = amount;
    }
    newAmount = Clamp(newAmount, minValue, maxValue);
    target.SetDosh(newAmount);
    //  Announce dosh change, if necessary
    announcer.Setup(target, instigator, othersConsole);
    if (newAmount > oldAmount) {
        announcer.AnnounceGainedDosh(newAmount - oldAmount);
    }
    if (newAmount < oldAmount) {
        announcer.AnnounceLostDosh(oldAmount - newAmount);
    }
}

defaultproperties
{
}
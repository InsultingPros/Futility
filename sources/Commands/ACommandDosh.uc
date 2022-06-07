/**
 *  Command for changing amount of money players have.
 *      Copyright 2021 Anton Tarasenko
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

var protected const int TGOTTEN, TLOST, TYOU_GAVE, TYOU_TAKEN, TOTHER_GAVE;
var protected const int TOTHER_TAKEN, TDOSH_FROM, TDOSH_TO, TYOURSELF, TDOSH;
var protected const int TTHEMSELVES;

protected function BuildData(CommandDataBuilder builder)
{
    builder.Name(P("dosh")).Summary(P("Changes amount of money."));
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
}

protected function ExecutedFor(
    EPlayer     player,
    CallData    result,
    EPlayer     callerPlayer)
{
    local int oldAmount, newAmount;
    local int amount, minValue, maxValue;
    //  Find min and max value boundaries
    minValue = result.options.GetIntBy(P("/min/minValue"), 0);
    maxValue = result.options.GetIntBy(P("/max/maxValue"), MaxInt);
    if (minValue > maxValue) {
        maxValue = minValue;
    }
    //  Change dosh
    oldAmount = player.GetDosh();
    amount = result.parameters.GetInt(P("amount"));
    if (result.subCommandName.IsEmpty()) {
        newAmount = oldAmount + amount;
    }
    else {
        //  This has to be "dosh set"
        newAmount = amount;
    }
    newAmount = Clamp(newAmount, minValue, maxValue);
    //  Announce dosh change, if necessary
    if (!result.options.HasKey(P("silent"))) {
        AnnounceDoshChange(player, callerPlayer, oldAmount, newAmount);
    }
    player.SetDosh(newAmount);
}

protected function AnnounceDoshChange(
    EPlayer player,
    EPlayer callerPlayer,
    int     oldAmount,
    int     newAmount)
{
    local bool affectingSelf;
    local Text amountDeltaAsText;
    local Text targetName, yourTargetName, callerName;
    callerName = callerPlayer.GetName();
    affectingSelf = callerPlayer.SameAs(player);
    if (affectingSelf)
    {
        yourTargetName  = T(TYOURSELF).Copy();
        targetName      = player.GetName();
    }
    else
    {
        yourTargetName  = T(TTHEMSELVES).Copy();
        targetName      = player.GetName();
    }
    if (newAmount > oldAmount)
    {
        amountDeltaAsText = _.text.FromInt(newAmount - oldAmount);
        if (!affectingSelf)
        {
            targetConsole.Write(T(TGOTTEN))
                .Write(amountDeltaAsText)
                .WriteLine(T(TDOSH));
        }
        callerConsole.Write(T(TYOU_GAVE))
            .Write(amountDeltaAsText)
            .Write(T(TDOSH_TO))
            .WriteLine(yourTargetName);
        othersConsole.Write(callerName)
            .Write(T(TOTHER_GAVE))
            .Write(amountDeltaAsText)
            .Write(T(TDOSH_TO))
            .WriteLine(targetName);
    }
    if (newAmount < oldAmount)
    {
        amountDeltaAsText = _.text.FromInt(oldAmount - newAmount);
        if (!affectingSelf)
        {
            targetConsole.Write(T(TLOST))
                .Write(amountDeltaAsText)
                .WriteLine(T(TDOSH));
        }
        callerConsole.Write(T(TYOU_TAKEN))
            .Write(amountDeltaAsText)
            .Write(T(TDOSH_FROM))
            .WriteLine(yourTargetName);
        othersConsole.Write(callerName)
            .Write(T(TOTHER_TAKEN))
            .Write(amountDeltaAsText)
            .Write(T(TDOSH_FROM))
            .WriteLine(targetName);
    }
    _.memory.Free(amountDeltaAsText);
    _.memory.Free(targetname);
    _.memory.Free(callerName);
}

defaultproperties
{
    TGOTTEN         = 0
    stringConstants(0)  = "You've {$TextPositive gotten} "
    TLOST           = 1
    stringConstants(1)  = "You've {$TextNegative lost} "
    TYOU_GAVE       = 2
    stringConstants(2)  = "You {$TextPositive gave} "
    TYOU_TAKEN      = 3
    stringConstants(3)  = "You {$TextNegative took} "
    TOTHER_GAVE     = 4
    stringConstants(4)  = " {$TextPositive gave} "
    TOTHER_TAKEN    = 5
    stringConstants(5)  = " {$TextNegative taken} "
    TDOSH           = 6
    stringConstants(6)  = " dosh"
    TDOSH_FROM      = 7
    stringConstants(7)  = " dosh from "
    TDOSH_TO        = 8
    stringConstants(8)  = " dosh to "
    TYOURSELF       = 9
    stringConstants(9)  = "yourself"
    TTHEMSELVES     = 10
    stringConstants(10) = "themselves"
}
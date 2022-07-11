/**
 *  Command for changing amount of money players have.
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
class ACommandUserData extends Command;

var private array<EPlayer> playerQueue;

//  TODO: Finish this command after JSON parameters are added
protected function BuildData(CommandDataBuilder builder)
{
    builder.Name(P("userdata")).Group(P("admin"))
        .Summary(P("Allows to read and write custom user data for players."));
    builder.RequireTarget();
    builder.ParamText(P("groupName"))
        .OptionalParams()
        .ParamText(P("dataName"))
        .Describe(P("Reads user data stored for targeted user under group"
            @ "{$TextEmphasis `groupName`} and name"
            @ "{$TextEmphasis `dataName`}. If {$TextEmphasis `dataName`} is"
            @ "omitted, the data inside the whjole group will be read."));
    builder.SubCommand(P("write"))
        .ParamText(P("groupName"))
        .ParamText(P("dataName"))
        .ParamObject(P("newData"))
        .Describe(P("Stores new user data {$TextEmphasis `newData`} for"
            @ "targeted user under group {$TextEmphasis `groupName`} and name"
            @ "{$TextEmphasis `dataName`}."));
}

protected function ExecutedFor(
    EPlayer     target,
    CallData    arguments,
    EPlayer     instigator)
{
    local AcediaObject  userData;

    if (arguments.subCommandName.IsEmpty())
    {
        target
            .GetIdentity()
            .ReadPersistentData(
                arguments.parameters.GetText(P("groupName")),
                arguments.parameters.GetText(P("dataName")))
            .connect = UserDataRead;
    }
    else
    {
        userData = arguments.parameters.GetHashTable(P("newData"));
        target
            .GetIdentity()
            .WritePersistentData(
                arguments.parameters.GetText(P("groupName")),
                arguments.parameters.GetText(P("dataName")),
                userData);
    }
    playerQueue[playerQueue.length] = target;
    target.NewRef();
}

private final function UserDataRead(
    Database.DBQueryResult  result,
    AcediaObject            userData,
    Database                source)
{
    local Text          targetPlayerName;
    local EPlayer       targetPlayer;
    local MutableText   asJSON;

    if (playerQueue.length <= 0)
    {
        targetPlayer
            .BorrowConsole()
            .UseColorOnce(_.color.TextFailure)
            .Write(F("There was an internal error with `userdata` command. "))
            .Write(P("Please report it!"));
        return;
    }
    targetPlayer = playerQueue[0];
    playerQueue.Remove(0, 1);
    if (result != DBR_Success)
    {
        targetPlayer
            .BorrowConsole()
            .UseColorOnce(_.color.TextFailure)
            .Write(F("There was an error reading user data, error code: "))
            .WriteLine(_.text.FromInt(int(result)));
        return;
    }
    targetPlayerName = targetPlayer.GetName();
    asJSON = _.json.PrettyPrint(userData);
    targetPlayer.BorrowConsole()
        .Write(F("{$TextPositive User data for player}"))
        .Write(targetPlayerName)
        .Write(P(":"))
        .WriteLine(asJSON);
    _.memory.Free(targetPlayer);
    _.memory.Free(asJSON);
    _.memory.Free(targetPlayerName);
}

defaultproperties
{
}
/**
 *  Command for working with databases.
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
class ACommandDB extends Command
    dependson(Database);

/**
 *  This command provides a text user interface to databases.
 *  It can perform two types of tasks:
 *      1.  Tasks that have to do with managing set of databases as a whole:
 *          listing them, their creation and deletion. For currently implemented
 *          local databases they work synchronously and are just simple bindings
 *          to the Acedia's API.
 *      2.  Tasks that edit a particular database: these require us to send
 *          database a query and then wait for the response. With these we
 *          cannot give an immediate reply, so we have to remember player that
 *          requested these queries to then relay him database's reply.
 *  Main problem with remembering a player for 2nd-type tasks is that,
 *  while highly unlikely, several different players may make their own requests
 *  while we are still waiting for the reply to the previous query.
 *  We could simply remember a queue of several players and then return them in
 *  a FIFO order (since databases guarantee orderly replies to their queries),
 *  but requests can also be towards different databases and, therefore,
 *  completed in a random order.
 *      To solve this we fill-in the waiting queue of pairs player-database that
 *  link player that made a request and database he made this request to.
 *  Once reply from any database arrives - we simply search and return
 *  the first player in our queue that made a request to this database.
 *  Thanks to the fact that databases reply to their queries in order of
 *  arrival - this will let us fetch precisely the players that were responsible
 *  for these requests. This logic is implemented in `PushPlayer()` and
 *  `PopPlayer()` methods.
 *      The rest of the methods are mostly straightforward callbacks that
 *  transform `Database`'s reply into text message for the player.
 */

//      Array of pairs is represented by two arrays of single values.
//      Arrays should be kept same length, elements with the same index
//  correspond to the same pair.
var protected array<Database>   queueWaitingListDatabases;
var protected array<EPlayer>    queueWaitingListPlayers;

//  Auxiliary structure that corresponds to database + JSON path from resolved
//  database link.
struct DBPointerPair
{
    var public Database     database;
    var public JSONPointer  pointer;
};

var protected const int TCREATE, TDELETE, TLIST, TREAD, TSIZE, TKEYS, TREMOVE;
var protected const int TWRITE, TWRITE_ARRAY, TWRITE_NULL, TWRITE_BOOLEAN;
var protected const int TWRITE_INTEGER, TWRITE_FLOAT, TWRITE_STRING, TINCREMENT;
var protected const int TDATABASE_NAME, TDATABASE_LINK, TJSON_VALUE;
var protected const int TOBJECT_KEYS_ARE, TOBJECT_SIZE_IS, TQUERY_COMPLETED;
var protected const int TQUERY_INVALID_POINTER, TQUERY_INVALID_DB;
var protected const int TQUERY_INVALID_DATA, TAVAILABLE_DATABASES, TDA_DELETED;
var protected const int TDB_DOESNT_EXIST, TDB_ALREADY_EXISTS, TDB_CREATED;
var protected const int TDB_CANNOT_BE_CREATED, TNO_DEFAULT_COMMAND, TBAD_DBLINK;

protected function BuildData(CommandDataBuilder builder)
{
    builder.Name(P("db")).Group(P("admin"))
        .Summary(P("Read and edit data in your databases."
        @ "Databases' values are addressed with links:"
        @ "\"<db_name>:<json_path>\""));
    builder.SubCommand(T(TCREATE))
        .ParamText(T(TDATABASE_NAME))
        .Describe(P("Creates new database with a specified name."));
    builder.SubCommand(T(TDELETE))
        .ParamText(T(TDATABASE_NAME))
        .Describe(P("Completely deletes specified database."));
    builder.SubCommand(T(TLIST))
        .Describe(P("Lists available databases."));
    builder.SubCommand(T(TREAD))
        .ParamText(T(TDATABASE_LINK))
        .Describe(P("Reads data from location given by the `databaseLink`."));
    builder.SubCommand(T(TSIZE))
        .ParamText(T(TDATABASE_LINK))
        .Describe(P("Gets amount of elements inside JSON array or object at"
            @ "location given by the `databaseLink`."));
    builder.SubCommand(T(TKEYS))
        .ParamText(T(TDATABASE_LINK))
        .Describe(P("Lists keys of JSON object at location given by"
            @ "the `databaseLink`."));
    builder.SubCommand(T(TREMOVE))
        .ParamText(T(TDATABASE_LINK))
        .Describe(P("Removes data from location given by the `databaseLink`."));
    builder.SubCommand(T(TWRITE))
        .ParamText(T(TDATABASE_LINK))
        .ParamObject(T(TJSON_VALUE))
        .Describe(P("Writes specified JSON object into location given by"
            @ "the `databaseLink`."));
    builder.SubCommand(T(TWRITE_ARRAY))
        .ParamText(T(TDATABASE_LINK))
        .ParamArray(T(TJSON_VALUE))
        .Describe(P("Writes specified JSON array into location given by"
            @ "the `databaseLink`."));
    builder.SubCommand(T(TWRITE_NULL))
        .ParamText(T(TDATABASE_LINK))
        .Describe(P("Writes specified null value into location given by"
            @ "the `databaseLink`."));
    builder.SubCommand(T(TWRITE_BOOLEAN))
        .ParamText(T(TDATABASE_LINK))
        .ParamBoolean(T(TJSON_VALUE))
        .Describe(P("Writes specified JSON boolean into location given by"
            @ "the `databaseLink`."));
    builder.SubCommand(T(TWRITE_INTEGER))
        .ParamText(T(TDATABASE_LINK))
        .ParamInteger(T(TJSON_VALUE))
        .Describe(P("Writes specified integer as JSON number into location"
            @ "given by the `databaseLink`."));
    builder.SubCommand(T(TWRITE_FLOAT))
        .ParamText(T(TDATABASE_LINK))
        .ParamNumber(T(TJSON_VALUE))
        .Describe(P("Writes specified float as JSON number into location"
            @ "given by the `databaseLink`."));
    builder.SubCommand(T(TWRITE_STRING))
        .ParamText(T(TDATABASE_LINK))
        .ParamText(T(TJSON_VALUE))
        .Describe(P("Writes specified JSON string into location given by"
            @ "the `databaseLink`."));
    builder.Option(T(TINCREMENT))
        .Describe(F("Specifying this option for any of the"
            @ "{$TextEmphasis 'write'} subcommands will cause them to append"
            @ "data to the old one, instead of rewriting it."));
}

protected function PushPlayer(EPlayer nextPlayer, Database callDatabase)
{
    queueWaitingListPlayers[queueWaitingListPlayers.length] =
        EPlayer(nextPlayer.Copy());
    queueWaitingListDatabases[queueWaitingListDatabases.length] = callDatabase;
}

protected function EPlayer PopPlayer(Database relevantDatabase)
{
    local int i;
    local EPlayer result;

    if (queueWaitingListPlayers.length <= 0)    return none;
    if (queueWaitingListDatabases.length <= 0)  return none;

    while (i < queueWaitingListDatabases.length)
    {
        if (queueWaitingListDatabases[i] != relevantDatabase)
        {
            result = queueWaitingListPlayers[i];
            queueWaitingListPlayers.Remove(i, 1);
            queueWaitingListDatabases.Remove(i, 1);
            break;
        }
        i += 1;
    }
    if (result != none && result.IsExistent()) {
        return result;
    }
    _.memory.Free(result);
    return none;
}

protected function Executed(CallData arguments, EPlayer instigator)
{
    local AcediaObject  valueToWrite;
    local DBPointerPair pair;
    local Text          subCommand;

    subCommand = arguments.subCommandName;
    //  Try executing on of the operation that manage multiple databases
    if (TryAPICallCommands(subCommand, instigator, arguments.parameters)) {
        return;
    }
    //  If we have failed - it has got to be one of the operations on
    //  a single database
    pair = TryLoadingDB(arguments.parameters.GetText(T(TDATABASE_LINK)));
    if (pair.database == none)
    {
        callerConsole.WriteLine(T(TBAD_DBLINK));
        return;
    }
    //  Remember the last player we are making a query to and make that query
    PushPlayer(instigator, pair.database);
    if (subCommand.StartsWith(T(TWRITE)))
    {
        valueToWrite = arguments.parameters.GetItem(T(TJSON_VALUE));
        if (arguments.options.HasKey(T(TINCREMENT)))
        {
            pair.database.IncrementData(pair.pointer, valueToWrite)
                .connect = DisplayResponse;
        }
        else
        {
            pair.database.WriteData(pair.pointer, valueToWrite)
                .connect = DisplayResponse;
        }
    }
    else if (subCommand.Compare(T(TREAD))) {
        pair.database.ReadData(pair.pointer).connect = DisplayData;
    }
    else if (subCommand.Compare(T(TSIZE))) {
        pair.database.GetDataSize(pair.pointer).connect = DisplaySize;
    }
    else if (subCommand.Compare(T(TKEYS))) {
        pair.database.GetDataKeys(pair.pointer).connect = DisplayKeys;
    }
    else if (subCommand.Compare(T(TREMOVE))) {
        pair.database.RemoveData(pair.pointer).connect = DisplayResponse;
    }
    _.memory.Free(pair.pointer);
}

//  Simple API calls
private function bool TryAPICallCommands(
    BaseText    subCommand,
    EPlayer     instigator,
    HashTable   commandParameters)
{
    local Text databaseName;
    if (subCommand.IsEmpty())
    {
        callerConsole.WriteLine(T(TNO_DEFAULT_COMMAND));
        return true;
    }
    else if (subCommand.Compare(T(TLIST)))
    {
        ListDatabases(instigator);
        return true;
    }
    else if (subCommand.Compare(T(TCREATE)))
    {
        databaseName = commandParameters.GetText(T(TDATABASE_NAME));
        CreateDatabase(instigator, databaseName);
        _.memory.Free(databaseName);
        return true;
    }
    else if (subCommand.Compare(T(TDELETE)))
    {
        databaseName = commandParameters.GetText(T(TDATABASE_NAME));
        DeleteDatabase(instigator, databaseName);
        _.memory.Free(databaseName);
        return true;
    }
    return false;
}

//  json pointer as `Text` -> `DBPointerPair` representation converter method
private function DBPointerPair TryLoadingDB(BaseText databaseLink)
{
    local DBPointerPair result;
    if (databaseLink == none) {
        return result;
    }
    result.database = _.db.Load(databaseLink);
    if (result.database == none) {
        return result;
    }
    result.pointer = _.db.GetPointer(databaseLink);
    return result;
}

protected function CreateDatabase(EPlayer instigator, Text databaseName)
{
    if (instigator == none) {
        return;
    }
    if (_.db.ExistsLocal(databaseName))
    {
        callerConsole.WriteLine(T(TDB_ALREADY_EXISTS));
        return;
    }
    if (_.db.NewLocal(databaseName) != none) {
        callerConsole.WriteLine(T(TDB_CREATED));
    }
    else {
        callerConsole.WriteLine(T(TDB_CANNOT_BE_CREATED));
    }
}

protected function DeleteDatabase(EPlayer instigator, Text databaseName)
{
    if (instigator == none) {
        return;
    }
    if (_.db.DeleteLocal(databaseName)) {
        callerConsole.WriteLine(T(TDA_DELETED));
    }
    else {
        callerConsole.WriteLine(T(TDB_DOESNT_EXIST));
    }
}

protected function ListDatabases(EPlayer instigator)
{
    local int           i;
    local array<Text>   availableDatabases;
    local ConsoleWriter console;

    if (instigator == none) {
        return;
    }
    availableDatabases = _.db.ListLocal();
    console = callerConsole;
    console.Write(T(TAVAILABLE_DATABASES));
    for (i = 0; i < availableDatabases.length; i += 1)
    {
        if (i > 0) {
            console.ResetColor().Write(P(", "));
        }
        console.UseColor(_.color.TextSubtle).Write(availableDatabases[i]);
    }
    console.ResetColor().Flush();
    _.memory.FreeMany(availableDatabases);
}

protected function OutputStatus(
    EPlayer                 instigator,
    Database.DBQueryResult  error)
{
    if (instigator == none) {
        return;
    }
    if (error == DBR_Success) {
        instigator.BorrowConsole().WriteLine(T(TQUERY_COMPLETED));
    }
    if (error == DBR_InvalidPointer) {
        instigator.BorrowConsole().WriteLine(T(TQUERY_INVALID_POINTER));
    }
    if (error == DBR_InvalidDatabase) {
        instigator.BorrowConsole().WriteLine(T(TQUERY_INVALID_DB));
    }
    if (error == DBR_InvalidData) {
        instigator.BorrowConsole().WriteLine(T(TQUERY_INVALID_DATA));
    }
}

protected function DisplayData(
    Database.DBQueryResult  result,
    AcediaObject            data,
    Database                source)
{
    local Text      printedJSON;
    local EPlayer   instigator;

    instigator = PopPlayer(source);
    OutputStatus(instigator, result);
    if (instigator != none && result == DBR_Success)
    {
        printedJSON = _.json.PrettyPrint(data).IntoText();
        instigator.BorrowConsole().Write(printedJSON).Flush();
        _.memory.Free(printedJSON);
        _.memory.Free(instigator);
        instigator = none;
    }
    _.memory.Free(data);
}

protected function DisplaySize(
    Database.DBQueryResult  result,
    int                     size,
    Database                source)
{
    local Text      sizeAsText;
    local EPlayer   instigator;

    instigator = PopPlayer(source);
    OutputStatus(instigator, result);
    if (instigator != none && result == DBR_Success)
    {
        sizeAsText = _.text.FromInt(size);
        instigator.BorrowConsole()
            .Write(T(TOBJECT_SIZE_IS))
            .Write(sizeAsText)
            .Flush();
        _.memory.Free(sizeAsText);
        _.memory.Free(instigator);
        instigator = none;
    }
}

protected function DisplayKeys(
    Database.DBQueryResult  result,
    ArrayList               keys,
    Database                source)
{
    local int           i;
    local Text          nextKey;
    local EPlayer       instigator;
    local ConsoleWriter console;

    instigator = PopPlayer(source);
    OutputStatus(instigator, result);
    if (keys == none) {
        return;
    }
    if (instigator != none && result == DBR_Success)
    {
        console = instigator.BorrowConsole();
        console.Write(T(TOBJECT_KEYS_ARE));
        for (i = 0; i < keys.GetLength(); i += 1)
        {
            if (i > 0) {
                console.ResetColor().Write(P(", "));
            }
            nextKey = keys.GetText(i);
            console.UseColor(_.color.jPropertyName).Write(nextKey);
            _.memory.Free(nextKey);
        }
        console.Flush();
        _.memory.Free(instigator);
        instigator = none;
    }
    _.memory.Free(keys);
}

protected function DisplayResponse(
    Database.DBQueryResult  result,
    Database                source)
{
    local EPlayer instigator;

    instigator = PopPlayer(source);
    OutputStatus(instigator, result);
    _.memory.Free(instigator);
}

defaultproperties
{
    TCREATE                 = 0
    stringConstants(0)      = "create"
    TDELETE                 = 1
    stringConstants(1)      = "delete"
    TLIST                   = 2
    stringConstants(2)      = "list"
    TREAD                   = 3
    stringConstants(3)      = "read"
    TSIZE                   = 4
    stringConstants(4)      = "size"
    TKEYS                   = 5
    stringConstants(5)      = "keys"
    TREMOVE                 = 6
    stringConstants(6)      = "remove"
    TWRITE                  = 7
    stringConstants(7)      = "write"
    TWRITE_ARRAY            = 8
    stringConstants(8)      = "write_array"
    TWRITE_NULL             = 9
    stringConstants(9)      = "write_null"
    TWRITE_BOOLEAN          = 10
    stringConstants(10)     = "write_boolean"
    TWRITE_INTEGER          = 11
    stringConstants(11)     = "write_integer"
    TWRITE_FLOAT            = 12
    stringConstants(12)     = "write_float"
    TWRITE_STRING           = 13
    stringConstants(13)     = "write_string"
    TINCREMENT              = 14
    stringConstants(14)     = "increment"
    TDATABASE_NAME          = 15
    stringConstants(15)     = "databaseName"
    TDATABASE_LINK          = 16
    stringConstants(16)     = "databaseLink"
    TJSON_VALUE             = 17
    stringConstants(17)     = "jsonValue"
    TOBJECT_KEYS_ARE        = 18
    stringConstants(18)     = "{$TextEmphasis Object keys are:} "
    TOBJECT_SIZE_IS         = 19
    stringConstants(19)     = "{$TextEmphasis Object size is:} "
    TQUERY_COMPLETED        = 20
    stringConstants(20)     = "{$TextPositive Database query was completed!}"
    TQUERY_INVALID_POINTER  = 21
    stringConstants(21)     = "{$TextNegative Query was provided with an invalid JSON pointer.}"
    TQUERY_INVALID_DB       = 22
    stringConstants(22)     = "{$TextNegative Operation could not finish because database is damaged and unusable.}"
    TQUERY_INVALID_DATA     = 23
    stringConstants(23)     = "{$TextNegative Query data is invalid.}"
    TAVAILABLE_DATABASES    = 24
    stringConstants(24)     = "{$TextEmphasis Available databases:} "
    TDA_DELETED             = 25
    stringConstants(25)     = "{$TextPositive Database was deleted.}"
    TDB_DOESNT_EXIST        = 26
    stringConstants(26)     = "{$TextNegative Database with specified name does not exist.}"
    TDB_ALREADY_EXISTS      = 27
    stringConstants(27)     = "{$TextNegative Database with specified name already exists.}"
    TDB_CREATED             = 28
    stringConstants(28)     = "{$TextPositive Database was created.}"
    TDB_CANNOT_BE_CREATED   = 29
    stringConstants(29)     = "{$TextNegative Database cannot be created.}"
    TNO_DEFAULT_COMMAND     = 30
    stringConstants(30)     = "{$TextNegative Default command does nothing. Use on of the sub-commands.}"
    TBAD_DBLINK             = 31
    stringConstants(31)     = "{$TextNegative Database could not be read for the specified link.}"
}
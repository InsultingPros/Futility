/**
 *  Command for managing (displaying + adding and removing to/items from it)
 *  player's inventory.
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
class ACommandInventory extends Command;

//      Load user-specified options into the boolean flags during'
//  `ExecutedFor()` and use them in auxiliary methods.
//      This is might be a questionable way of doing things, but it allows to
//  avoid passing flags in copious amounts to auxiliary methods and
//  does not overcomplicate logic
var private bool flagAll, flagForce, flagAmmo, flagKeep;
var private bool flagEquip, flagHidden, flagGroups;

var protected const int TINVENTORY, TADD, TREMOVE, TITEMS, TEQUIP, TALL, TKEEP;
var protected const int THIDDEN, TFORCE, TAMMO, TLIST, TLISTS_NAMES, TSET;
var protected const int TLISTS_SKIPPED;

protected function BuildData(CommandDataBuilder builder)
{
    builder.Name(T(TINVENTORY))
        .Summary(P("Manages player's inventory."))
        .Describe(P("Command for displaying and editing players' inventories."
            @ "If called without specifying subcommand - simply displays"
            @ "targeted player's inventory."));
    builder.RequireTarget();
    builder.SubCommand(T(TADD))
        .OptionalParams()
        .ParamTextList(T(TITEMS))
        .Describe(P("This command adds items (based on listed templates) to"
            @ "the targeted player's inventory."
            @ "Instead of templates item aliases can be specified."));
    builder.SubCommand(T(TREMOVE))
        .OptionalParams()
        .ParamTextList(T(TITEMS))
        .Describe(P("This command removes items (based on listed templates)"
            @ "from the targeted player's inventory."
            @ "Instead of templates item aliases can be specified."));
    builder.SubCommand(T(TSET))
        .OptionalParams()
        .ParamTextList(T(TITEMS))
        .Describe(P("This command acts like combination of two commands -"
            @ "first removing all items from the player's current inventory and"
            @ "then adding specified items. first clears inventory"
            @ "(based on specified options) and then "));
    builder.Option(T(TEQUIP))
        .Describe(F("Affect items currently equipped by the targeted player."
            @ "Releveant for a {$TextEmphasis remove} subcommand."));
    builder.Option(T(TLIST))
        .Describe(P("Include weapons from specified group into the list."))
        .ParamTextList(T(TLISTS_NAMES));
    builder.Option(T(TAMMO))
        .Describe(P("When adding weapons - signals that their"
            @ "ammo / charge / whatever has to be filled after addition."));
    builder.Option(T(TKEEP))
        .Describe(F("Removing items by default means simply destroying them."
            @ "This flag makes command to try and keep them in some form."
            @ "Success for all items is not guaranteed."));
    builder.Option(T(THIDDEN))
        .Describe(F("Some of the items in the inventory are"
            @ "{$TextEmphasis hidden} and are not supposed to be seem by"
            @ "the player. To avoid weird behavior, {$TextEmphasis inventory}"
            @ "command by default ignores them when affecting groups of items"
            @ "(like when removing all items) unless they're directly"
            @ "specified. This flag tells it to also affect hidden items."));
    builder.Option(T(TFORCE))
        .Describe(P("Sometimes adding and removing items is impossible due to"
            @ "the limitations imposed by the game. This option allows to"
            @ "ignore some of those limitation."));
    builder.Option(T(TALL), P("A"))
        .Describe(F("This flag is used when removing items. If user has"
            @ "specified any weapon templates - it means"
            @ "\"remove all items with these tempaltes from inventory\","
            @ "but if user has not specified any templated it simply means"
            @ "\"remove all items from the inventory\"."));
}

protected function ExecutedFor(
    EPlayer     player,
    CallData    result,
    EPlayer     callerPlayer)
{
    local InventoryTool tool;
    local DynamicArray  itemsArray, specifiedLists;
    LoadUserFlags(result.options);
    tool = class'InventoryTool'.static.CreateFor(player);
    if (tool == none) {
        return;
    }
    itemsArray = result.parameters.GetDynamicArray(T(TITEMS));
    specifiedLists = result.options.GetDynamicArrayBy(P("/list/lists names"));
    if (result.subCommandName.IsEmpty()) {
        tool.ReportInventory(callerConsole, flagHidden);
    }
    else if (result.subCommandName.Compare(T(TADD))) {
        SubCommandAdd(tool, itemsArray, specifiedLists);
    }
    else if (result.subCommandName.Compare(T(TREMOVE))) {
        SubCommandRemove(tool, itemsArray, specifiedLists);
    }
    else if (result.subCommandName.Compare(T(TSET)))
    {
        tool.RemoveAllItems(flagKeep, flagForce, flagHidden);
        SubCommandAdd(tool, itemsArray, specifiedLists);
    }
    tool.ReportChanges(callerPlayer, callerConsole, IRT_Caller);
    tool.ReportChanges(callerPlayer, targetConsole, IRT_Target);
    tool.ReportChanges(callerPlayer, othersConsole, IRT_Others);
    _.memory.Free(tool);
}

protected function SubCommandAdd(
    InventoryTool   tool,
    DynamicArray    itemsArray,
    DynamicArray    specifiedLists)
{
    local int           i, j;
    local int           itemsAmount;
    local array<Text>   itemsFromLists;
    if (tool == none) {
        return;
    }
    if (itemsArray != none) {
        itemsAmount = itemsArray.GetLength();
    }
    //  Add items user listed manually
    //  Use `itemsAmount` because `itemsArray` can be `none`
    for (i = 0; i < itemsAmount; i += 1) {
        tool.AddItem(itemsArray.GetText(i), flagForce, flagAmmo);
    }
    //  Add items from specified lists
    itemsFromLists = LoadAllItemsLists(specifiedLists);
    for (i = 0; i < itemsFromLists.length; i += 1) {
        tool.AddItem(itemsFromLists[j], flagForce, flagAmmo);
    }
    _.memory.FreeMany(itemsFromLists);
}

protected function SubCommandRemove(
    InventoryTool   tool,
    DynamicArray    itemsArray,
    DynamicArray    specifiedLists)
{
    local int           i, j;
    local int           itemsAmount;
    local array<Text>   itemsFromLists;
    if (tool == none) {
        return;
    }
    if (itemsArray != none) {
        itemsAmount = itemsArray.GetLength();
    }
    //  Remove due to "--all" option
    if (flagAll && itemsAmount <= 0)
    {
        tool.RemoveAllItems(flagKeep, flagForce, flagHidden);
        return;
    }
    //  Remove due to "--equip" option
    if (flagEquip) {
        tool.RemoveEquippedItems(flagKeep, flagForce, flagHidden);
    }
    //  Remove items user listed manually
    //  Use `itemsAmount` because `itemsArray` can be `none`
    for (i = 0; i < itemsAmount; i += 1) {
        tool.RemoveItem(itemsArray.GetText(i), flagKeep, flagForce, flagAll);
    }
    //  Remove items from specified lists
    itemsFromLists = LoadAllItemsLists(specifiedLists);
    for (i = 0; i < itemsFromLists.length; i += 1) {
        tool.RemoveItem(itemsFromLists[j], flagKeep, flagForce, flagAll);
    }
    _.memory.FreeMany(itemsFromLists);
}

protected function LoadUserFlags(AssociativeArray options)
{
    if (options == none)
    {
        flagAll     = false;
        flagForce   = false;
        flagAmmo    = false;
        flagKeep    = false;
        flagEquip   = false;
        flagHidden  = false;
        flagGroups  = false;
        return;
    }
    flagAll     = options.HasKey(T(TALL));
    flagForce   = options.HasKey(T(TFORCE));
    flagAmmo    = options.HasKey(T(TAMMO));
    flagKeep    = options.HasKey(T(TKEEP));
    flagEquip   = options.HasKey(T(TEQUIP));
    flagHidden  = options.HasKey(T(THIDDEN));
    flagGroups  = options.HasKey(T(TLIST));
}

protected function array<Text> LoadAllItemsLists(DynamicArray specifiedLists)
{
    local int           i, j;
    local array<Text>   result;
    local array<Text>   nextItemBatch;
    local array<Text>   availableLists;
    local ReportTool    badLists;
    if (specifiedLists == none) {
        return result;
    }
    badLists = ReportTool(_.memory.Allocate(class'ReportTool'));
    badLists.Initialize(T(TLISTS_SKIPPED));
    availableLists = _.kf.templates.GetAvailableLists();
    for (i = 0; i < specifiedLists.Getlength(); i += 1)
    {
        nextItemBatch =
            LoadItemsList(specifiedLists.GetText(i), availableLists, badLists);
        for (j = 0; j < nextItemBatch.length; j += 1) {
            result[result.length] = nextItemBatch[j];
        }
    }
    badLists.Report(callerConsole);
    _.memory.Free(badLists);
    _.memory.FreeMany(availableLists);
    return result;
}

protected function array<Text> LoadItemsList(
    Text        listName,
    array<Text> availableLists,
    ReportTool  badLists)
{
    local int           i;
    local array<Text>   emptyArray;
    if (listName == none) {
        return emptyArray;
    }
    //  Try exact matching first
    for (i = 0; i < availableLists.length; i += 1)
    {
        if (availableLists[i].Compare(listName, SCASE_INSENSITIVE)) {
            return _.kf.templates.GetItemList(availableLists[i]);
        }
    }
    //  Prefix matching otherwise
    for (i = 0; i < availableLists.length; i += 1)
    {
        if (availableLists[i].StartsWith(listName, SCASE_INSENSITIVE)) {
            return _.kf.templates.GetItemList(availableLists[i]);
        }
    }
    badLists.Item(listName);
    return emptyArray;
}

defaultproperties
{
    TINVENTORY      = 0
    stringConstants(0)  = "inventory"
    TADD            = 1
    stringConstants(1)  = "add"
    TREMOVE         = 2
    stringConstants(2)  = "remove"
    TITEMS          = 3
    stringConstants(3)  = "items"
    TEQUIP          = 4
    stringConstants(4)  = "equip"
    TALL            = 5
    stringConstants(5)  = "all"
    TKEEP           = 6
    stringConstants(6)  = "keep"
    THIDDEN         = 7
    stringConstants(7)  = "hidden"
    TFORCE          = 8
    stringConstants(8)  = "force"
    TAMMO           = 9
    stringConstants(9)  = "ammo"
    TLIST           = 10
    stringConstants(10) = "list"
    TLISTS_NAMES    = 11
    stringConstants(11) = "lists names"
    TSET            = 12
    stringConstants(12) = "set"
    TLISTS_SKIPPED  = 13
    stringConstants(13) = "Following lists could not have been found and will be {$TextFailure skipped}:"
}
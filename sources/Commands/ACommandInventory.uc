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

var protected const int TINVENTORY, TADD, TREMOVE, TITEMS, TEQUIP, TALL, TKEEP;
var protected const int THIDDEN, TFORCE, TAMMO, TALL_WEAPONS;

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
    builder.Option(T(TEQUIP))
        .Describe(F("Affect items currently equipped by the targeted player."
            @ "Releveant for a {$TextEmphasis remove} subcommand."));
    builder.Option(T(TALL))
        .Describe(F("This flag tells editing commands to affect all items."
            @ "When adding items it means \"all available weapons in the game\""
            @ "and when removing it means \"all weapons in"
            @ "the player's inventory\"."));
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
    builder.Option(T(TAMMO), P("A"))
        .Describe(P("When adding weapons - signals that their"
            @ "ammo / charge / whatever has to be filled after addition."));
}

protected function ExecutedFor(
    EPlayer     player,
    CallData    result,
    EPlayer     callerPlayer)
{
    local ConsoleWriter publicWriter;
    local InventoryTool tool;
    tool = class'InventoryTool'.static.CreateFor(player);
    if (tool == none) {
        return;
    }
    if (result.subCommandName.IsEmpty())
    {
        tool.ReportInventory(   callerPlayer.BorrowConsole(),
                                result.options.HasKey(T(THIDDEN)));
    }
    else if (result.subCommandName.Compare(T(TADD)))
    {
        SubCommandAdd(  tool, result.parameters.GetDynamicArray(T(TITEMS)),
                        result.options.HasKey(T(TALL)),
                        result.options.HasKey(T(TFORCE)),
                        result.options.HasKey(T(TAMMO)));
    }
    else if (result.subCommandName.Compare(T(TREMOVE)))
    {
        SubCommandRemove(   tool,
                            result.parameters.GetDynamicArray(T(TITEMS)),
                            result.options.HasKey(T(TALL)),
                            result.options.HasKey(T(TFORCE)),
                            result.options.HasKey(T(TKEEP)),
                            result.options.HasKey(T(TEQUIP)),
                            result.options.HasKey(T(THIDDEN)));
    }
    tool.ReportChanges(callerPlayer, player.BorrowConsole(), false);
    publicWriter = _.console.ForAll().ButPlayer(callerPlayer);
    tool.ReportChanges(callerPlayer, publicWriter, true);
    _.memory.Free(tool);
    _.memory.Free(publicWriter);
}

protected function SubCommandAdd(
    InventoryTool   tool,
    DynamicArray    templateList,
    bool            flagAll,
    bool            doForce,
    bool            doFillAmmo)
{
    if (flagAll) {
        AddAllItems(tool, doForce, doFillAmmo);
    }
    else {
        AddGivenTemplates(tool, templateList, doForce, doFillAmmo);
    }
}

protected function SubCommandRemove(
    InventoryTool   tool,
    DynamicArray    templateList,
    bool            flagAll,
    bool            doForce,
    bool            doKeep,
    bool            flagEquip,
    bool            flagHidden)
{
    if (flagAll)
    {
        tool.RemoveAllItems(doKeep, doForce, flagHidden);
        return;
    }
    if (flagEquip) {
        tool.RemoveEquippedItems(doKeep, doForce, flagHidden);
    }
    RemoveGivenTemplates(tool, templateList, doForce, doKeep);
}

protected function AddAllItems(
    InventoryTool   tool,
    bool            doForce,
    bool            doFillAmmo)
{
    local int           i;
    local array<Text>   allTempaltes;
    if (tool == none) {
        return;
    }
    allTempaltes = _.kf.templates.GetItemList(T(TALL_WEAPONS));
    for (i = 0; i < allTempaltes.length; i += 1) {
        tool.AddItem(allTempaltes[i], doForce, doFillAmmo);
    }
    _.memory.FreeMany(allTempaltes);
}

protected function AddGivenTemplates(
    InventoryTool   tool,
    DynamicArray    templateList,
    bool            doForce,
    bool            doFillAmmo)
{
    local int i;
    if (tool == none)           return;
    if (templateList == none)   return;

    for (i = 0; i < templateList.GetLength(); i += 1) {
        tool.AddItem(templateList.GetText(i), doForce, doFillAmmo);
    }
}

protected function RemoveGivenTemplates(
    InventoryTool   tool,
    DynamicArray    templateList,
    bool            doForce,
    bool            doKeep)
{
    local int i;
    if (tool == none)           return;
    if (templateList == none)   return;

    for (i = 0; i < templateList.GetLength(); i += 1) {
        tool.RemoveItem(templateList.GetText(i), doKeep, doForce);
    }
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
    TALL_WEAPONS    = 10
    stringConstants(10) = "all weapons"
}
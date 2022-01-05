/**
 *  Command for giving players weapons or other items.
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
class ACommandGive extends Command;

protected function BuildData(CommandDataBuilder builder)
{
    builder.Name(P("give")).Summary(P("Gives player specified weapon / item."));
    builder.RequireTarget();
    builder.ParamTextList(P("items"))
        .Describe(P("Gives players a specified item."));
    builder.Option(P("force"))
        .Describe(P("Due to inventory limitations, this command might refuse to"
            @ "add specified weapons. Using this flag makes it try to resolve"
            @ "situation and allow adding specified weapon. But results are"
            @ "still not guaranteed."));
    builder.Option(P("clear"))
        .Describe(F("Clears target's inventory before adding new weapons."
            @ "By default destroys inventory. Setting optional parameter to"
            @ "{$TypeBoolean 'true'} will make game try to keep items,"
            @ "e.g. by just dropping them on the floor."))
        .OptionalParams()
        .ParamBoolean(P("keep-items"));
}

protected function ExecutedFor(
    EPlayer     player,
    CallData    result,
    EPlayer     callerPlayer)
{
    local int               i;
    local bool              doForce;
    local Text              itemTemplate, itemName;
    local array<Text>       addedItems, rejectedItems;
    local EInventory        inventory;
    local EItemTemplateInfo templateInfo;
    local DynamicArray      itemsToAdd;
    inventory       = player.GetInventory();
    itemsToAdd      = result.parameters.GetDynamicArray(P("items"));
    doForce         = result.options.HasKey(P("force"));
    if (result.options.HasKey(P("clear"))) {
        inventory.RemoveAll(result.options.GetBoolBy(P("/clear/keep-items")));
    }
    for (i = 0; i < itemsToAdd.GetLength(); i += 1)
    {
        itemTemplate = GetTemplate(itemsToAdd.GetText(i));
        templateInfo = _.kf.GetItemTemplateInfo(itemTemplate);
        if (templateInfo != none) {
            itemName = templateInfo.GetName();
        }
        else {
            itemName = itemTemplate.Copy();
        }
        if (inventory.AddTemplate(itemTemplate, doForce)) {
            addedItems[addedItems.length] = itemName;
        }
        else {
            rejectedItems[rejectedItems.length] = itemName;
        }
        _.memory.Free(itemTemplate);
        itemTemplate = none;
        itemName = none;
    }
    ReportResultsToCaller(callerPlayer, player, addedItems, rejectedItems);
    AnnounceGivingItems(callerPlayer, player, addedItems);
    _.memory.Free(inventory);
    _.memory.FreeMany(addedItems);
    _.memory.FreeMany(rejectedItems);
}

protected function Text GetTemplate(Text userItemName)
{
    if (userItemName == none) {
        return none;
    }
    if (userItemName.StartsWith(P("$"))) {
        return _.alias.ResolveWeapon(userItemName, true);
    }
    return userItemName.Copy();
}

protected function bool GiveItemTo(
    Text        itemTemplate,
    EInventory  inventory,
    bool        doForce)
{
    local bool addedSuccessfully;
    if (itemTemplate == none) {
        return false;
    }
    if (!itemTemplate.StartsWith(P("$"))) {
        addedSuccessfully = inventory.AddTemplate(itemTemplate);
    }
    else
    {
        itemTemplate = _.alias.ResolveWeapon(itemTemplate, true);
        addedSuccessfully = inventory.AddTemplate(itemTemplate, doForce);
        _.memory.Free(itemTemplate);
    }
    return addedSuccessfully;
}

protected function ReportResultsToCaller(
    EPlayer     caller,
    EPlayer     target,
    array<Text> addedItems,
    array<Text> rejectedItems)
{
    local int           i;
    local Text          targetName;
    local ConsoleWriter console;
    if (addedItems.length <= 0 && rejectedItems.length <= 0) {
        return;
    }
    console = caller.BorrowConsole();
    targetName = target.GetName();
    console.Write(F("{$TextEmphasis Giving} weapons to "))
        .Write(targetName).Write(P(": "));
    targetName.FreeSelf();
    if (addedItems.length > 0)
    {
        console.Write(F("{$TextPositive successfully} gave "));
        for (i = 0; i < addedItems.length; i += 1)
        {
            if (i > 0)
            {
                if (i == addedItems.length - 1) {
                    console.Write(P(" and "));
                }
                else {
                    console.Write(P(", "));
                }
            }
            console.UseColorOnce(_.color.TextSubtle).Write(addedItems[i]);
        }
    }
    if (rejectedItems.length > 0)
    {
        if (addedItems.length > 0) {
            console.Write(F(", {$TextNegative but} "));
        }
        console.Write(F("{$TextNegative failed} to give "));
        for (i = 0; i < rejectedItems.length; i += 1)
        {
            if (i > 0)
            {
                if (i == rejectedItems.length - 1) {
                    console.Write(P(" and "));
                }
                else {
                    console.Write(P(", "));
                }
            }
            console.UseColorOnce(_.color.TextSubtle).Write(rejectedItems[i]);
        }
    }
    console.Flush();
}

protected function AnnounceGivingItems(
    EPlayer     caller,
    EPlayer     target,
    array<Text> addedItems)
{
    local int               i;
    local Text              targetName;
    local MutableText       message;
    local ConsoleWriter     console;
    local Text.Formatting   itemNameFormatting;
    if (addedItems.length <= 0) {
        return;
    }
    message = _.text.Empty();
    itemNameFormatting = _.text.FormattingFromColor(_.color.TextSubtle);
    message.Append(F("{$TextPositive given}: "));
    for (i = 0; i < addedItems.length; i += 1)
    {
        if (i > 0)
        {
            if (i == addedItems.length - 1) {
                message.Append(P(" and "));
            }
            else {
                message.Append(P(", "));
            }
        }
        message.Append(addedItems[i], itemNameFormatting);
    }
    targetName = target.GetName();
    console = _.console.ForAll().ButPlayer(caller).ButPlayer(target)
        .Write(targetName).Write(P(" was ")).Say(message);
    if (caller != target) {
        console.ForPlayer(target).Write(P("You were ")).Say(message);
    }
    console.FreeSelf();
    message.FreeSelf();
    targetName.FreeSelf();
}

defaultproperties
{
}
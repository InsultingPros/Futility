/**
 *      Auxiliary object for working with player's inventory and making reports
 *  about it. Simplifies code for inventory commands themselves by
 *  taking care of actual item addition/removal and reporting about successes,
 *  failures and inventory status.
 *      This tool is supposed to be created for one player and provides wrapper
 *  methods for his usual inventory methods that take care of information
 *  collection about outcome of operations and then reporting on them.
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
class InventoryTool extends AcediaObject;

enum InventoryReportTarget
{
    IRT_Instigator,
    IRT_Target,
    IRT_Others
};

/**
 *  Every instance of this class is created for a particular player and that
 *  player cannot be changed. It allows:
 *  1.  This object allows for editing player's inventory in a way that allows
 *      it to produce a human-readable report about the changes.
 *      Call `AddItem()`, `RemoveItem()` or `RemoveAllItems()` and then call
 *      `ReportChanges()` to write changes made into the `ConsoleWriter`.
 *  2.  `ReportInventory()` summarizes player's inventory.
 */

//  References to player (for whom this tool was created)...
var private EPlayer     targetPlayer;
//  ...and his inventory (for easy access)
var private EInventory  targetInventory;

/**
 *  `ListBuilder`s for 6 different cases:
 *      ~   two of "...Verbose" and "...Failed" ones make reports about
 *          successes and failures of adding and removals to the instigator of
 *          these changes;
 *      ~   two other ones (`itemsAdded` and `itemsRemoved`) make reports about
 *          successful changes to everybody else present on the server.
 *  Supposed to be created via `CreateFor()` method.
 */
var public ListBuilder itemsAdded;
var public ListBuilder itemsRemoved;
var public ListBuilder itemsAddedPrivate;
var public ListBuilder itemsRemovedPrivate;
var public ListBuilder itemsAdditionFailed;
var public ListBuilder itemsRemovalFailed;

var private TextTemplate templateItemsAdded, templateItemsRemoved;
var private TextTemplate templateItemsAddedVerbose, templateItemsRemovedVerbose;
var private TextTemplate templateAdditionFailed, templateRemovalFailed;

var const int TINSTIGATOR, TTARGET, TRESOLVED_INTO, TTILDE_QUOTE;
var const int TITEM_MISSING, TITEM_NOT_REMOVABLE, TUNKNOWN, TVISIBLE;
var const int TDISPLAYING_INVENTORY, THEADER_COLON, TDOT_SPACE, TCOLON_SPACE;
var const int TCOMMA_SPACE, TSPACE, TOUT_OF, THIDDEN_ITEMS, TDOLLAR, TYOU;
var const int TTHEMSELVES, TFAULTY_INVENTORY_IMPLEMENTATION;

public static function StaticConstructor()
{
    if (StaticConstructorGuard()) {
        return;
    }
    default.templateItemsAdded = __().text.MakeTemplate_S(
        "%%instigator%% {$TextPositive added} following weapons to"
        @ "%%target%%: ");
    default.templateItemsRemoved = __().text.MakeTemplate_S(
        "%%instigator%% {$TextNegative removed} following weapons from"
        @ "%%target%%: ");
    default.templateItemsAddedVerbose = __().text.MakeTemplate_S(
        "Weapons {$TextPositive added} to %%target%%: ");
    default.templateItemsRemovedVerbose = __().text.MakeTemplate_S(
        "Weapons {$TextNegative removed} from %%target%%: ");
    default.templateAdditionFailed = __().text.MakeTemplate_S(
        "Weapons we've {$TextFailure failed} to add to %%target%%: ");
    default.templateRemovalFailed = __().text.MakeTemplate_S(
        "Weapons we've {$TextFailure failed} to remove from %%target%%: " );
}

protected function Constructor()
{
    itemsAdded          = ListBuilder(_.memory.Allocate(class'ListBuilder'));
    itemsRemoved        = ListBuilder(_.memory.Allocate(class'ListBuilder'));
    itemsAddedPrivate   = ListBuilder(_.memory.Allocate(class'ListBuilder'));
    itemsRemovedPrivate = ListBuilder(_.memory.Allocate(class'ListBuilder'));
    itemsAdditionFailed = ListBuilder(_.memory.Allocate(class'ListBuilder'));
    itemsRemovalFailed  = ListBuilder(_.memory.Allocate(class'ListBuilder'));
}

protected function Finalizer()
{
    //  Deallocate report tools
    _.memory.Free(itemsAdded);
    _.memory.Free(itemsRemoved);
    _.memory.Free(itemsAddedPrivate);
    _.memory.Free(itemsRemovedPrivate);
    _.memory.Free(itemsAdditionFailed);
    _.memory.Free(itemsRemovalFailed);
    itemsAdded          = none;
    itemsRemoved        = none;
    itemsAddedPrivate   = none;
    itemsRemovedPrivate = none;
    itemsAdditionFailed = none;
    itemsRemovalFailed  = none;
    //  Deallocate player references
    _.memory.Free(targetPlayer);
    _.memory.Free(targetInventory);
    targetPlayer    = none;
    targetInventory = none;
}

/**
 *  Creates new `InventoryTool` instance for a given player `target`.
 *
 *  @param  target  Player for which to create new `InventoryTool`.
 *  @return `InventoryTool` created for the given player - not a copy of any
 *      preexisting instance. `none` iff `target == none` or refers to
 *      a non-existent player.
 */
public static final function InventoryTool CreateFor(EPlayer target)
{
    local InventoryTool newInventoryTool;

    if (target == none)         return none;
    if (!target.IsExistent())   return none;

    newInventoryTool =
        InventoryTool(__().memory.Allocate(class'InventoryTool'));
    newInventoryTool.targetPlayer       = EPlayer(target.Copy());
    newInventoryTool.targetInventory    = target.GetInventory();
    return newInventoryTool;
}

//  Checks whether reference to the `EPlayer` that caller `InventoryTool` was
//  created for is still valid.
private final function bool TargetPlayerIsInvalid()
{
    if (targetPlayer == none)       return true;
    if (!targetPlayer.IsExistent()) return true;

    return false;
}

/**
 *  Resets `InventoryTool`, forgetting about changes made with it so far.
 */
public final function Reset()
{
    itemsAddedPrivate.Reset();
    itemsRemovedPrivate.Reset();
    itemsAdded.Reset();
    itemsRemoved.Reset();
    itemsAdditionFailed.Reset();
    itemsRemovalFailed.Reset();
}

//      Makes "`resolvedWhat` resolved into `intoWhat`" line
//      In case `resolvedWhat == intoWhat` just returns copy of
//  original `resolvedWhat`
private function MutableText MakeResolvedIntoLine(
    BaseText resolvedWhat,
    BaseText intoWhat)
{
    if (resolvedWhat == none) {
        return none;
    }
    if (_.text.IsEmpty(intoWhat) || resolvedWhat.Compare(intoWhat)) {
        return resolvedWhat.MutableCopy();
    }
    return _.text.Empty()
        .Append(T(TTILDE_QUOTE))
        .Append(resolvedWhat)
        .Append(T(TRESOLVED_INTO))
        .Append(intoWhat)
        .Append(T(TTILDE_QUOTE));
}

//  Tries to fill ammo for the `item` in case it is a weapon
private function TryFillAmmo(EItem item)
{
    local EWeapon itemAsWeapon;

    if (item == none) {
        return;
    }
    itemAsWeapon = EWeapon(item.As(class'EWeapon'));
    if (itemAsWeapon != none)
    {
        itemAsWeapon.FillAmmo();
        _.memory.Free(itemAsWeapon);
    }
}

/**
 *  Adds a new item, based on user provided name `userProvidedName`.
 *
 *  @param  userProvidedName    Name of the inventory, provided by the user.
 *      If it is started with "$", then tool tried to treat it as
 *      an alias first. If it either does not start with "$" or does not
 *      correspond to a valid alias - it is treated as a template.
 *  @param  doForce             Set to `true` if we must try to add an item
 *      even if it normally cannot be added.
 *  @param  doFillAmmo          Set to `true` if we must also fill ammo reserves
 *      of weapons we have added to the full.
 */
public function AddItem(
    BaseText    userProvidedName,
    bool        doForce,
    bool        doFillAmmo)
{
    local EItem         addedItem;
    local MutableText   resolvedLine;
    local Text          realItemName, itemTemplate, failureReason;

    if (TargetPlayerIsInvalid())    return;
    if (userProvidedName == none)   return;

    //  Get template in case alias was specified
    //  (`itemTemplate` cannot be `none`, since `userProvidedName != none`)
    if (userProvidedName.StartsWith(T(TDOLLAR))) {
        itemTemplate = _.alias.ResolveWeapon(userProvidedName, true);
    }
    else {
        itemTemplate = userProvidedName.Copy();
    }
    //  The only way we can fail in a valid way is when API says we will
    //  via `CanAddTemplateExplain()`
    failureReason = targetInventory
        .CanAddTemplateExplain(itemTemplate, doForce);
    if (failureReason != none)
    {
        itemsAdditionFailed.Item(userProvidedName).Comment(failureReason);
        _.memory.Free(failureReason);
        _.memory.Free(itemTemplate);
        return;
    }
    //  Actually try to add specified item
    addedItem = targetInventory.AddTemplate(itemTemplate, doForce);
    if (addedItem != none)
    {
        if (doFillAmmo) {
            TryFillAmmo(addedItem);
        }
        realItemName = addedItem.GetName();
        resolvedLine = MakeResolvedIntoLine(userProvidedName, itemTemplate);
        itemsAdded.Item(realItemName);
        itemsAddedPrivate.Item(realItemName).Comment(resolvedLine);
        _.memory.Free(realItemName);
        _.memory.Free(resolvedLine);
        _.memory.Free(addedItem);
    }
    else
    {
        //  `CanAddTemplateExplain()` told us that we should not have failed,
        //  so complain about bad API
        itemsAdditionFailed.Item(userProvidedName)
            .Comment(T(TFAULTY_INVENTORY_IMPLEMENTATION));
    }
    _.memory.Free(itemTemplate);
}

/**
 *  Removes a specified item, based on user provided name `userProvidedName`.
 *
 *  @param  userProvidedName    Name of inventory, provided by the user.
 *      If it is started with "$", then tool tried to treat it as
 *      an alias first. If it either does not start with "$" or does not
 *      correspond to a valid alias - it is treated as a template.
 *  @param  doKeep              Set to `true` if item should be preserved
 *      (or, at least, attempted to be preserved) and not simply destroyed.
 *  @param  doForce             Set to `true` if we must try to remove an item
 *      even if it normally cannot be removed.
 *  @param  doRemoveAll         Set to `true` to remove all instances of given
 *      template and `false` to only remove one.
 */
public function RemoveItem(
    BaseText    userProvidedName,
    bool        doKeep,
    bool        doForce,
    bool        doRemoveAll)
{
    local bool          itemWasMissing;
    local Text          realItemName, itemTemplate;
    local MutableText   resolvedLine;
    local EItem         storedItem;

    if (TargetPlayerIsInvalid())    return;
    if (userProvidedName == none)   return;

    //  Get template in case alias was specified
    //  (`itemTemplate` cannot be `none`, since `userProvidedName != none`)
    if (userProvidedName.StartsWith(T(TDOLLAR))) {
        itemTemplate = _.alias.ResolveWeapon(userProvidedName, true);
    }
    else {
        itemTemplate = userProvidedName.Copy();
    }
    //  Check if item is even in the inventory
    storedItem = targetInventory.GetTemplateItem(itemTemplate);
    if (storedItem == none)
    {
        //  If not, we still need to attempt to remove it, as it can be
        //  "merged" into another item
        itemWasMissing = true;
        realItemName = P("").Copy();
    }
    else {
        //  Need to remember the name before removing the item
        realItemName = storedItem.GetName();
    }
    if (targetInventory
        .RemoveTemplate(itemTemplate, doKeep, doForce, doRemoveAll))
    {
        resolvedLine = MakeResolvedIntoLine(userProvidedName, itemTemplate);
        itemsRemoved.Item(realItemName);
        itemsRemovedPrivate.Item(realItemName).Comment(resolvedLine);
        _.memory.Free(resolvedLine);
    }
    //  Try to guess why operation failed
    //  (no special explanation method is present in the API)
    else if (itemWasMissing) {  //  likely because it was missing
        itemsRemovalFailed.Item(userProvidedName).Comment(T(TITEM_MISSING));
    }
    else if (!doForce && !storedItem.IsRemovable()) //  simply was not removable
    {
        itemsRemovalFailed.Item(userProvidedName)
            .Comment(T(TITEM_NOT_REMOVABLE));
    }
    else {  //  no idea about the reason
        itemsRemovalFailed.Item(userProvidedName).Comment(T(TUNKNOWN));
    }
    _.memory.Free(storedItem);
    _.memory.Free(realItemName);
    _.memory.Free(itemTemplate);
}

//  Auxiliary method for detecting and reporting about removed items by
/// comparing lists of `EItem` interfeaces created beofer and after removal
private function DetectAndReportRemovedItems(
    out array<EItem>    itemsAfterRemoval,
    array<EItem>        itemsBeforeRemoval,
    array<BaseText>     itemNames,
    bool                doForce)
{
    local int   i, j;
    local bool  itemWasRemoved;

    for (i = 0; i < itemsBeforeRemoval.length; i += 1)
    {
        itemWasRemoved = true;
        //  If item was not destroyed - double check whether it got removed
        if (itemsBeforeRemoval[i].IsExistent())
        {
            for (j = 0; j < itemsAfterRemoval.length; j += 1)
            {
                if (itemsBeforeRemoval[i].SameAs(itemsAfterRemoval[j]))
                {
                    _.memory.Free(itemsAfterRemoval[j]);
                    itemsAfterRemoval.Remove(j, 1);
                    itemWasRemoved = false;
                    break;
                }
            }
        }
        if (itemWasRemoved)
        {
            itemsRemoved.Item(itemNames[i]);
            itemsRemovedPrivate.Item(itemNames[i]);
        }
        else if (doForce || itemsBeforeRemoval[i].IsRemovable()) {
            itemsRemovalFailed.Item(itemNames[i]).Comment(T(TUNKNOWN));
        }
    }
}

/**
 *  Removes all items from the player's inventory.
 *
 *  @param  doKeep          Set to `true` if items should be preserved
 *      (or, at least, attempted to be preserved) and not simply destroyed.
 *  @param  doForce         Set to `true` if we must try to remove an item
 *      even if it normally cannot be removed.
 *  @param  includeHidden   Set to `true` if "hidden" items should also be
 *      targeted by this method. These are items player cannot directly see in
 *      their inventory, usually serving some sort of technical role.
 */
public function RemoveAllItems(bool doKeep, bool doForce, bool includeHidden)
{
    local int           i;
    local array<Text>   itemNames;
    local array<EItem>  itemsBeforeRemoval, itemsAfterRemoval;

    if (TargetPlayerIsInvalid()) {
        return;
    }
    //      Remove all items!
    //      Remember what items we have had before to output them and
    //  what items we have after removal to detect what we have actually
    //  removed.
    //      This is necessary, since (to an extent depending on flags)
    //  some items might not be removable.
    if (includeHidden) {
        itemsBeforeRemoval = targetInventory.GetAllItems();
    }
    else {
        itemsBeforeRemoval = targetInventory.GetTagItems(T(TVISIBLE));
    }
    for (i = 0; i < itemsBeforeRemoval.length; i += 1) {
        itemNames[i] = itemsBeforeRemoval[i].GetName();
    }
    targetInventory.RemoveAll(doKeep, doForce, includeHidden);
    itemsAfterRemoval = targetInventory.GetAllItems();
    //  Figure out what items are actually gone and report about them
    DetectAndReportRemovedItems(    itemsAfterRemoval,
                                    itemsBeforeRemoval, itemNames,
                                    doForce);
    _.memory.FreeMany(itemNames);
    _.memory.FreeMany(itemsBeforeRemoval);
    _.memory.FreeMany(itemsAfterRemoval);
}

/**
 *  Removes all equipped items from the player's inventory.
 *
 *  @param  doKeep          Set to `true` if items should be preserved
 *      (or, at least, attempted to be preserved) and not simply destroyed.
 *  @param  doForce         Set to `true` if we must try to remove an item
 *      even if it normally cannot be removed.
 *  @param  includeHidden   Set to `true` if "hidden" items should also be
 *      targeted by this method. These are items player cannot directly see in
 *      their inventory, usually serving some sort of technical role.
 */
public function RemoveEquippedItems(
    bool doKeep,
    bool doForce,
    bool includeHidden)
{
    local int           i;
    local EItem         nextItem;
    local Text          nextItemName;
    local array<EItem>  equippedItems;

    if (TargetPlayerIsInvalid()) {
        return;
    }
    equippedItems = targetInventory.GetEquippedItems();
    for (i = 0; i < equippedItems.length; i += 1)
    {
        nextItem = equippedItems[i];
        if (!nextItem.IsExistent())                             continue;
        if (!includeHidden && !nextItem.HasTag(T(TVISIBLE)))    continue;
    
        nextItemName = nextItem.GetName();
        //  Try to guess the reason we cannot remove the item
        if (!doForce && !nextItem.IsRemovable())
        {
            itemsRemovalFailed
                .Item(nextItemName)
                .Comment(T(TITEM_NOT_REMOVABLE));
        }
        else if (!targetInventory.Remove(nextItem, doKeep, doForce))
        {
            itemsRemovalFailed
                .Item(nextItemName)
                .Comment(T(TUNKNOWN));
        }
        _.memory.Free(nextItemName);
        nextItemName = none;
    }
    _.memory.FreeMany(equippedItems);
}

/**
 *  Tells `InventoryTool` which player is responsible for the changes it is
 *  reporting. This information is used to choose the phrasing of the reported
 *  messages.
 *
 *  @param  instigator  Player that supposedly requested all the changes done by
 *      the calller `InventoryTool`.
 */
public final function SetupReportInstigator(EPlayer instigator)
{
    local MutableText instigatorName, targetName;

    if (TargetPlayerIsInvalid())    return;
    if (instigator == none)         return;

    instigatorName = ColorNickname(instigator.GetName());
    if (!targetPlayer.SameAs(instigator)) {
        targetName = ColorNickname(targetPlayer.GetName());
    }
    else {
        targetName = T(TYOU).MutableCopy();
    }
    //  For instigator
    default.templateItemsAdded.Reset().TextArg(T(TINSTIGATOR), instigatorName);
    default.templateItemsRemoved
        .Reset()
        .TextArg(T(TINSTIGATOR), instigatorName);
    //  For everybody else
    default.templateAdditionFailed.Reset().TextArg(T(TTARGET), targetName);
    default.templateRemovalFailed.Reset().TextArg(T(TTARGET), targetName);
    default.templateItemsAddedVerbose.Reset().TextArg(T(TTARGET), targetName);
    default.templateItemsRemovedVerbose.Reset().TextArg(T(TTARGET), targetName);
    _.memory.Free(instigatorName);
    _.memory.Free(targetName);
}

private final function MutableText ColorNickname(/* take */ BaseText nickname)
{
    if (nickname == none) {
        return none;
    }
    return nickname
        .IntoMutableText()
        .ChangeDefaultColor(_.color.LightGray);
}

/**
 *  Reports changes made to the player's inventory so far.
 *
 *  Ability to provide this reports is pretty much the main reason for
 *  using `InventoryTool`
 *  @param  blamedPlayer    Player that should be listed as the one who caused
 *      the changes.
 *  @param  writer          `ConsoleWriter` that will be used to output report.
 *      Method does nothing if given `writer` is `none`.
 *  @param  reportTarget    For who is this report meant to? For general public
 *      and target only actually occured changes are reported (with different
 *      phrasing), but for instigator changes that tool failed to do will also
 *      be reported.
 */
public final function ReportChanges(
    EPlayer                 instigator,
    ConsoleWriter           writer,
    InventoryReportTarget   reportTarget)
{
    if (TargetPlayerIsInvalid()) {
        return;
    }
    if (reportTarget != IRT_Instigator)
    {
        SwapTargetNameInTemplates(instigator, reportTarget);
        ReportWeaponList(writer, default.templateItemsRemoved, itemsRemoved);
        ReportWeaponList(writer, default.templateItemsAdded, itemsAdded);
        return;
    }
    ReportWeaponList(
        writer,
        default.templateItemsRemovedVerbose,
        itemsRemovedPrivate);
    ReportWeaponList(
        writer,
        default.templateRemovalFailed,
        itemsRemovalFailed);
    ReportWeaponList(
        writer,
        default.templateItemsAddedVerbose,
        itemsAddedPrivate);
    ReportWeaponList(
        writer,
        default.templateAdditionFailed,
        itemsAdditionFailed);
}

private final function SwapTargetNameInTemplates(
    EPlayer                 instigator,
    InventoryReportTarget   reportTarget)
{
    local MutableText targetName;

    if (TargetPlayerIsInvalid()) {
        return;
    }
    if (!targetPlayer.SameAs(instigator)) {
        targetName = ColorNickname(targetPlayer.GetName());
    }
    else if (reportTarget == IRT_Target) {
        targetName = T(TYOU).MutableCopy();
    }
    else {
        targetName = T(TTHEMSELVES).MutableCopy();
    }
    default.templateItemsAdded.TextArg(T(TTARGET), targetName);
    default.templateItemsRemoved.TextArg(T(TTARGET), targetName);
    _.memory.Free(targetName);
}

private final function ReportWeaponList(
    ConsoleWriter   writer,
    TextTemplate    header,
    ListBuilder     builder)
{
    local MutableText output;

    if (writer == none)     return;
    if (builder == none)    return;
    if (builder.IsEmpty())  return;

    if (header != none)
    {
        output = header.CollectFormattedM();
        writer.Write(output);
        _.memory.Free(output);
        output = none;
    }
    output = builder.GetMutable();
    writer.WriteLine(output);
    _.memory.Free(output);
}

//  TODO: Use `ListBuilder` for the below method?
/**
 *  Command that outputs summary of the player's inventory.
 *
 *  @param  writer          `ConsoleWriter` into which to output information.
 *      Method does nothing if given `writer` is `none`.
 *  @param  includeHidden   Set to `true` if "hidden" items should also be
 *      targeted by this method. These are items player cannot directly see in
 *      their inventory, usually serving some sort of technical role.
 */
public final function ReportInventory(ConsoleWriter writer, bool includeHidden)
{
    local int           i;
    local int           lineCounter;
    local array<EItem>  availableItems;
    local Text          playerName;

    if (writer == none)             return;
    if (TargetPlayerIsInvalid())    return;

    playerName = targetPlayer.GetName();
    writer.Flush()
        .Write(T(TDISPLAYING_INVENTORY))
        .UseColorOnce(_.color.White).Write(playerName)
        .Write(T(THEADER_COLON)).Flush();
    lineCounter = 1;
    availableItems = targetInventory.GetAllItems();
    //  First show visible items
    for (i = 0; i < availableItems.length; i += 1)
    {
        if (availableItems[i].HasTag(T(TVISIBLE)))
        {
            AppendItemInfo(writer, availableItems[i], lineCounter);
            lineCounter += 1;
        }
    }
    //  Once more pass for non-visible items, to display them at the end
    if (includeHidden)
    {
        writer.Write(T(THIDDEN_ITEMS)).Flush();
        for (i = 0; i < availableItems.length; i += 1)
        {
            if (!availableItems[i].HasTag(T(TVISIBLE)))
            {
                AppendItemInfo(writer, availableItems[i], lineCounter);
                lineCounter += 1;
            }
        }
    }
    _.memory.Free(playerName);
    _.memory.FreeMany(availableItems);
}

private final function AppendItemInfo(
    ConsoleWriter   writer,
    EItem           item,
    int             lineNumber)
{
    local Text          itemName;
    local Text          lineNumberAsText;
    local EWeapon       itemAsWeapon;
    local Mutabletext   allAmmoInfo;

    if (writer == none) return;
    if (item == none)   return;

    itemName            = item.GetName();
    lineNumberAsText    = _.text.FromInt(lineNumber);
    writer.Write(lineNumberAsText)
        .Write(T(TDOT_SPACE))
        .UseColorOnce(_.color.TextEmphasis).Write(itemName);
    //  Try to display additional ammo info if this is a weapon
    itemAsWeapon = EWeapon(item.As(class'EWeapon'));
    if (itemAsWeapon != none)
    {
        allAmmoInfo = DisplayAllAmmoInfo(itemAsWeapon);
        if (allAmmoInfo != none) {
            writer.Write(T(TCOLON_SPACE)).Write(allAmmoInfo);
        }
        _.memory.Free(itemAsWeapon);
        _.memory.Free(allAmmoInfo);
    }
    writer.Flush();
    _.memory.Free(itemName);
    _.memory.Free(lineNumberAsText);
}

private final function MutableText DisplayAllAmmoInfo(EWeapon weapon)
{
    local int           i;
    local array<EAmmo>  allAmmo;
    local MutableText   builder;

    allAmmo = weapon.GetAvailableAmmo();
    if (allAmmo.length == 0) {
        return none;
    }
    builder = _.text.Empty();
    for (i = 0; i < allAmmo.length; i += 1)
    {
        if (i > 0) {
            builder.Append(T(TCOMMA_SPACE));
        }
        AppendAmmoInstanceInfo(builder, allAmmo[i]);
    }
    _.memory.FreeMany(allAmmo);
    return builder;
}

private final function AppendAmmoInstanceInfo(MutableText builder, EAmmo ammo)
{
    local Text ammoName;

    if (ammo == none) {
        return;
    }
    ammoName = ammo.GetName();
    builder.AppendString(   string(ammo.GetTotalAmount()),
                            _.text.FormattingFromColor(_.color.TypeNumber))
        .Append(T(TSPACE)).Append(ammoName).Append(T(TOUT_OF))
        .AppendString(  string(ammo.GetMaxTotalAmount()),
                        _.text.FormattingFromColor(_.color.TypeNumber));
    _.memory.Free(ammoName);
}

defaultproperties
{
    TINSTIGATOR                         = 0
    stringConstants(0)  = "instigator"
    TTARGET                             = 1
    stringConstants(1)  = "target"
    TRESOLVED_INTO                      = 2
    stringConstants(2)  = "` resolved into `"
    TTILDE_QUOTE                        = 3
    stringConstants(3)  = "`"
    TFAULTY_INVENTORY_IMPLEMENTATION    = 4
    stringConstants(4)  = "faulty inventory implementation"
    TITEM_MISSING                       = 5
    stringConstants(5)  = "item missing"
    TITEM_NOT_REMOVABLE                 = 6
    stringConstants(6)  = "item not removable"
    TUNKNOWN                            = 7
    stringConstants(7)  = "unknown"
    TVISIBLE                            = 8
    stringConstants(8)  = "visible"
    TDISPLAYING_INVENTORY               = 9
    stringConstants(9)  = "{$TextHeader Displaying inventory for player }"
    THEADER_COLON                       = 10
    stringConstants(10) = "{$TextHeader :}"
    TDOT_SPACE                          = 11
    stringConstants(11) = ". "
    TCOLON_SPACE                        = 12
    stringConstants(12) = ": "
    TCOMMA_SPACE                        = 13
    stringConstants(13) = ", "
    TSPACE                              = 14
    stringConstants(14) = " "
    TOUT_OF                             = 15
    stringConstants(15) = " out of "
    THIDDEN_ITEMS                       = 16
    stringConstants(16) = "{$TextSubHeader Hidden items:}"
    TDOLLAR                             = 17
    stringConstants(17) = "$"
    TYOU                                = 18
    stringConstants(18) = "you"
    TTHEMSELVES                         = 19
    stringConstants(19) = "themselves"
}
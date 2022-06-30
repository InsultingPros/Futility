/**
 *      Many different Futility's commands need to output lists of items
 *  separated by commas, each item possibly containing comments in
 *  the parentheses (also separated by commas). This class provides necessary
 *  functionality.
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
class ListBuilder extends AcediaObject;

/**
 *  # `ListBuilder`
 *
 *      Many different Futility's commands need to output lists of items
 *  separated by commas, each item possibly containing comments in
 *  the parentheses (also separated by commas). This class provides necessary
 *  functionality.
 *      Example of such list:
 *  "item1, item2 (comment1, comment2), item3 (just_comment), item4, item5".
 *
 *  ##  Usage
 *
 *      1.  Use `Item()` method to add new items (they will be listed after
 *          list header + whitespace, separated by commas and whitespaces ", ");
 *      2.  Use `Comment()` method to specify comments for the item (they will
 *          be listed between the paranthesisasd after the corresponding item).
 *          Comments will be added to the last item, added via `Item()` call.
 *          If no items were added, specified comment will be discarded.
 *      3.  Use `Get()` / `GetMutable()` methods to return list built so far.
 *      4.  Use `Reset()` to forget all the items and comments
 *          (but not list header), allowing to start forming a new report.
 */

//  Represents one item + all of its comments
struct FutilityListItem
{
    var Text        itemTitle;
    var array<Text> comments;
};
//  All items recorded reported thus far
var private array<FutilityListItem> collectedItems;

var const int TCAUSE, TTARGET, TCOMMA, TSPACE, TCOMMA_SPACE;
var const int TSPACE_OPEN_PARANSIS, TCLOSE_PARANSIS;

protected function Finalizer()
{
    Reset();
}

/**
 *  Checks if caller `ListBuilder` already has any items added.
 *
 *  @return `true` if caller `ListBuilder` doesn't have any items added and
 *      `false` if it has at least one.
 */
public final function bool IsEmpty()
{
    return (collectedItems.length <= 0);
}

/**
 *  Adds new `item` to the current report.
 *
 *  @param  item    Text to be included into the report as an item.
 *      One should avoid using commas or parantheses inside an `item`, but
 *      this limitation is not checked or prevented by `Item()` method.
 *      Does nothing if `item == none` (`Comment()` will continue adding
 *      comments to the previously added item).
 *  @return Reference to the caller `ListBuilder` to allow for method chaining.
 */
public final function ListBuilder Item(BaseText item)
{
    local FutilityListItem newItem;

    if (item == none) {
        return self;
    }
    newItem.itemTitle = item.Copy();
    collectedItems[collectedItems.length] = newItem;
    return self;
}

/**
 *  Adds new `comment` to the last added `item` in the current report.
 *
 *  @param  comment Text to be included into the report as a comment to
 *      the last added item. One should avoid using commas or parantheses inside
 *      a `comment`, but this limitation is not checked or prevented by
 *      `Comment()` method.
 *      Does nothing if `comment == none` or no items were added thuis far.
 *  @return Reference to the caller `ListBuilder` to allow for method chaining.
 */
public final function ListBuilder Comment(BaseText comment)
{
    local array<Text> itemComments;

    if (comment == none)            return self;
    if (collectedItems.length == 0) return self;

    itemComments = collectedItems[collectedItems.length - 1].comments;
    itemComments[itemComments.length] = comment.Copy();
    collectedItems[collectedItems.length - 1].comments = itemComments;
    return self;
}

/**
 *  Returns list, assembled from items and their comment specified so far as
 *  `Text`.
 *
 *  @see `GetMutable()`, `IntoText()`, `IntoMutableText()`
 *
 *  @return Assembled list of specified items with specified comments.
 */
public final function Text Get()
{
    local MutableText mutableResult;

    mutableResult = GetMutable();
    if (mutableResult != none) {
        return mutableResult.IntoText();
    }
    return none;
}

/**
 *  Returns list, assembled from items and their comment specified so far as
 *  `MutableText`.
 *
 *  @see `Get()`, `IntoText()`, `IntoMutableText()`
 *
 *  @return Assembled list of specified items with specified comments.
 */
public final function MutableText GetMutable()
{
    local int           i, j;
    local MutableText   result;
    local array<Text>   itemComments;

    if (collectedItems.length == 0) {
        return _.text.Empty();
    }
    result = _.text.Empty();
    for (i = 0; i < collectedItems.length; i += 1)
    {
        if (i > 0) {
            result.Append(T(TCOMMA_SPACE));
        }
        result.Append(collectedItems[i].itemTitle);
        itemComments = collectedItems[i].comments;
        if (itemComments.length > 0) {
            result.Append(T(TSPACE_OPEN_PARANSIS));
        }
        for (j = 0; j < itemComments.length; j += 1)
        {
            if (j > 0) {
                result.Append(T(TCOMMA_SPACE));
            }
            result.Append(itemComments[j]);
        }
        if (itemComments.length > 0) {
            result.Append(T(TCLOSE_PARANSIS));
        }
    }
    return result;
}

/**
 *  Converts caller `Listbuilder` into list, assembled from items and their
 *  comment specified so far as `Text`.
 *  Caller `ListBuilder()` is atuomatically deallocated.
 *
 *  @see `Get()`, `GetMutable()`, `IntoMutableText()`
 *
 *  @return Assembled list of specified items with specified comments.
 */
public final function Text IntoText()
{
    local Text result;

    result = Get();
    FreeSelf();
    return result;
}

/**
 *  Converts caller `Listbuilder` into list, assembled from items and their
 *  comment specified so far as `MutableText`.
 *  Caller `ListBuilder()` is atuomatically deallocated.
 *
 *  @see `Get()`, `GetMutable()`, `IntoText()`
 *
 *  @return Assembled list of specified items with specified comments.
 */
public final function MutableText IntoMutableText()
{
    local MutableText result;

    result = GetMutable();
    FreeSelf();
    return result;
}

/**
 *  Forgets all items or comments specified for the caller `ListBuilder` so far,
 *  allowing to start forming a new report.
 *
 *  @return Reference to the caller `ListBuilder` to allow for method chaining.
 */
public final function ListBuilder Reset()
{
    local int i;

    for (i = 0; i < collectedItems.length; i += 1)
    {
        _.memory.Free(collectedItems[i].itemTitle);
        _.memory.FreeMany(collectedItems[i].comments);
    }
    collectedItems.length = 0;
    return self;
}

defaultproperties
{
    TCAUSE                  = 0
    stringConstants(0)  = "%%instigator%%"
    TTARGET                 = 1
    stringConstants(1)  = "%%target%%"
    TCOMMA                  = 2
    stringConstants(2)  = ","
    TCOMMA_SPACE            = 3
    stringConstants(3)  = ", "
    TSPACE_OPEN_PARANSIS    = 4
    stringConstants(4)  = " ("
    TCLOSE_PARANSIS         = 5
    stringConstants(5)  = ")"
}
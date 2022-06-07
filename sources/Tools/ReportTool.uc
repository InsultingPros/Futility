/**
 *      Auxiliary object for outputting lists of values (with optional comments)
 *  for Futility's commands. Some of the commands need to report that one of
 *  the player did something to affect the other and then list the changes.
 *  This tool is made to simplify forming such reports.
 *      Produced reports have a form of "<list header, noting who affected who>:
 *  item1 (detail), item2, item3 (detail1, detail2)".
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
class ReportTool extends AcediaObject;

/**
 *  How to use:
 *      1.  Specify "list header" via `Initialize()` method right after creating
 *          a new instance of `ReportTool`. It can contain "%cause%" and
 *          "%target%" substrings, that will be replaces with approprtiate
 *          parameters of `Report()` method when it is invoked;
 *      2.  Use `Item()` method to add new items (they will be listed after
 *          list header + whitespace, separated by commas and whitespaces ", ");
 *      3.  Use `Detail()` method to specify details for the item (they will be
 *          listed between the paranthesisasd after the corresponding item).
 *          Details will be added to the last item, added via `Item()` call.
 *          If no items were added, specified details will be discarded.
 *      4.  Use `Report()` method to feed the `ConsoleWriter` with report that
 *          has been assebled so far.
 *      5. Use `Reset()` to forget all the items and details
 *          (but not list header), allowing to start forming a new report.
 */

//      Header template (with possible "%cause%" and "%target%" placeholders)
//  for the lists this `ReportTool` will generate.
//      Doubles as a way to remember whether `ReportTool` was already
//  initialized (iff `headerTemplate != none`).
var private Text headerTemplate;

//  Represents one item + all of its details.
struct ReportItem
{
    var Text        itemTitle;
    var array<Text> details;
};
//  All items recorded reported thus far
var private array<ReportItem> itemsToReport;

var const int TCAUSE, TTARGET, TCOMMA, TSPACE, TSPACE_OPEN_PARANSIS;
var const int TCLOSE_PARANSIS;

protected function Finalizer()
{
    Reset();
    _.memory.Free(headerTemplate);
    headerTemplate = none;
}

/**
 *  Initialized a new `ReportTool` with appropriate template to serve as
 *  a header.
 *
 *  Template (`template`) is allowed to contain "%cause%" and "%target%"
 *  placeholder substrings that will be replaced with corresponding names of the
 *  player that caused a change we are reporting and player affefcted by
 *  that change.
 *
 *  @param  template    Template for the header of the reports made by
 *      the caller `ReportTool`.
 *      Method does nothing (initialization fails) iff `template == none`.
 */
public final function Initialize(Text template)
{
    if (template == none) {
        return;
    }
    headerTemplate = template.Copy();
}

/**
 *  Adds new `item` to the current report.
 *
 *  @param  item    Text to be included into the report as an item.
 *      One should avoid using commas or parantheses inside an `item`, but
 *      this limitation is not checked or prevented by `Item()` method.
 *      Does nothing if `item == none` (`Detail()` will continue adding details
 *      to the previously added item).
 *  @return Reference to the caller `ReportTool` to allow for method chaining.
 */
public final function ReportTool Item(Text item)
{
    local ReportItem newItem;
    if (headerTemplate == none) return self;
    if (item == none)           return self;

    newItem.itemTitle = item.Copy();
    itemsToReport[itemsToReport.length] = newItem;
    return self;
}

/**
 *  Adds new `detail` to the last added `item` in the current report.
 *
 *  @param  detail  Text to be included into the report as a detail to
 *      the last added item. One should avoid using commas or parantheses inside
 *      a `detail`, but this limitation is not checked or prevented by
 *      `Detail()` method.
 *      Does nothing if `detail == none` or no items were added thuis far.
 *  @return Reference to the caller `ReportTool` to allow for method chaining.
 */
public final function ReportTool Detail(Text detail)
{
    local array<Text> detailToReport;
    if (headerTemplate == none)     return self;
    if (detail == none)             return self;
    if (itemsToReport.length == 0)  return self;

    detailToReport = itemsToReport[itemsToReport.length - 1].details;
    detailToReport[detailToReport.length] = detail.Copy();
    itemsToReport[itemsToReport.length - 1].details = detailToReport;
    return self;
}

/**
 *  Outputs report assembled thus far into the provided `ConsoleWriter`.
 *  Reports will be made only if at least one items was added (see `Item()`).
 *
 *  @param  writer  `ConsoleWriter` to output report into.
 *  @param  cause   Player that caused the change this report is about.
 *      Their name will replace "%cause%" substring in the header template
 *      (if it is contained there).
 *  @param  target  Player that was affected by the change this report is about.
 *      Their name will replace "%target%" substring in the header template
 *      (if it is contained there).
 *  @return Reference to the caller `ReportTool` to allow for method chaining.
 */
public final function ReportTool Report(
    ConsoleWriter writer,
    optional Text cause,
    optional Text target)
{
    local int           i, j;
    local MutableText   intro;
    local array<Text>   detailToReport;
    if (headerTemplate == none)     return self;
    if (itemsToReport.length == 0)  return self;
    if (writer == none)             return self;

    intro = headerTemplate.MutableCopy()
        .Replace(T(TCAUSE), cause)
        .Replace(T(TTARGET), target);
    writer.Flush().Write(intro);
    _.memory.Free(intro);
    for (i = 0; i < itemsToReport.length; i += 1)
    {
        if (i > 0) {
            writer.Write(T(TCOMMA));
        }
        writer.Write(T(TSPACE)).Write(itemsToReport[i].itemTitle);
        detailToReport = itemsToReport[i].details;
        if (detailToReport.length > 0) {
            writer.Write(T(TSPACE_OPEN_PARANSIS));
        }
        for (j = 0; j < detailToReport.length; j += 1)
        {
            if (j > 0) {
                writer.Write(P(", "));
            }
            writer.Write(detailToReport[j]);
        }
        if (detailToReport.length > 0) {
            writer.Write(T(TCLOSE_PARANSIS));
        }
    }
    writer.Flush();
    return self;
}

/**
 *  Forgets all items or details specified for the caller `ReportTool` so far,
 *  allowing to start forming a new report. Does not reset template header,
 *  specified in the `Initialize()` method.
 *
 *  @return Reference to the caller `ReportTool` to allow for method chaining.
 */
public final function ReportTool Reset()
{
    local int i;
    for (i = 0; i < itemsToReport.length; i += 1)
    {
        _.memory.Free(itemsToReport[i].itemTitle);
        _.memory.FreeMany(itemsToReport[i].details);
    }
    if (itemsToReport.length > 0) {
        itemsToReport.length = 0;
    }
    return self;
}

defaultproperties
{
    TCAUSE                  = 0
    stringConstants(0)  = "%cause%"
    TTARGET                 = 1
    stringConstants(1)  = "%target%"
    TCOMMA                  = 2
    stringConstants(2) = ","
    TSPACE                  = 3
    stringConstants(3)  = " "
    TSPACE_OPEN_PARANSIS    = 4
    stringConstants(4)  = " ("
    TCLOSE_PARANSIS         = 5
    stringConstants(5)  = ")"
}
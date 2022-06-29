/**
 *      Interface class for providing static methods for working with errors,
 *  that can arise from parsing formatted strings.
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
class FormattingReportTool extends AcediaObject
    abstract;

var private const int TCASES, TREPORT_HEADER, TUNMATCHED_SINGLE;
var private const int TUNMATCHED_MULTIPLE, TEMPTY_TAG_SINGLE;
var private const int TEMPTY_TAG_MULTIPLE, TBAD_COLOR, TBAD_GRADIENT_POINT;
var private const int TBADSHORT_TAG;

/**
 *  Outputs report about formatting errors given by `errors` array.
 *  Reports will be made only if at least one error exists.
 *
 *  @param  writer  `ConsoleWriter` to output report into.
 *  @param  errors  Formatting errors to report.
 */
public final static function Report(
    ConsoleWriter                                       writer,
    array<FormattingErrorsReport.FormattedStringError>  errors)
{
    local int           i;
    local ListBuilder   builder;
    local MutableText   itemList;

    builder = ListBuilder(__().memory.Allocate(class'ListBuilder'));
    writer.Write(T(default.TREPORT_HEADER));
    for (i = 0; i < errors.length; i += 1)
    {
        if (errors[i].type == FSE_UnmatchedClosingBrackets)
        {
            ReportCount(
                errors[i],
                builder,
                default.TUNMATCHED_SINGLE,
                default.TUNMATCHED_MULTIPLE);
        }
        else if (errors[i].type == FSE_EmptyColorTag)
        {
            ReportCount(
                errors[i],
                builder,
                default.TEMPTY_TAG_SINGLE,
                default.TEMPTY_TAG_MULTIPLE);
        }
        else if (errors[i].type == FSE_BadColor) {
            builder.Item(T(default.TBAD_COLOR)).Comment(errors[i].cause);
        }
        else if (errors[i].type == FSE_BadShortColorTag) {
            builder.Item(T(default.TBADSHORT_TAG)).Comment(errors[i].cause);
        }
        else if (errors[i].type == FSE_BadGradientPoint)
        {
            builder
                .Item(T(default.TBAD_GRADIENT_POINT))
                .Comment(errors[i].cause);
        }
    }
    itemList = builder.IntoMutableText();
    writer.WriteLine(itemList);
    __().memory.Free(itemList);
}

/**
 *  `FormattedStringError` is a struct that can contain a `Text` object that
 *  needs to be deallocated. This is convenience method that does that.
 *
 *  @param  errors  Errors, whos `cause` filds must deallocated.
 */
public final static function FreeErrors(
    array<FormattingErrorsReport.FormattedStringError>  errors)
{
    local int i;

    for (i = 0; i < errors.length; i += 1) {
        __().memory.Free(errors[i].cause);
    }
}

private final static function ReportCause(
    FormattingErrorsReport.FormattedStringError error,
    ListBuilder                                 builder,
    int                                         sentence)
{
    local MutableText causeBuilder;

    if (error.cause == none) {
        return;
    }
    builder.Item(T(sentence));
    causeBuilder = __().text.FromIntM(error.count).Append(T(default.TCASES));
    builder.Comment(causeBuilder);
    __().memory.Free(causeBuilder);
}

//  In the methods below, do not double check the error type in the following
//  errors or whether `builder != none`
private final static function ReportCount(
    FormattingErrorsReport.FormattedStringError error,
    ListBuilder                                 builder,
    int                                         singleSentence,
    int                                         multipleSentence)
{
    local MutableText commentBuilder;

    if (error.count < 1) {
        return;
    }
    if (error.count == 1)
    {
        builder.Item(T(singleSentence));
        return;
    }
    builder.Item(T(multipleSentence));
    commentBuilder = __().text.FromIntM(error.count).Append(T(default.TCASES));
    builder.Comment(commentBuilder);
    __().memory.Free(commentBuilder);
}

defaultproperties
{
    TCASES              = 0
    stringConstants(0)  = " cases"
    TREPORT_HEADER      = 1
    stringConstants(1)  = "{$TextFailure Following formatting errors were found}:"
    TUNMATCHED_SINGLE   = 2
    stringConstants(2)  = "unmatched closing curly bracket '&}'"
    TUNMATCHED_MULTIPLE = 3
    stringConstants(3)  = "several unmatched closing curly brackets '&}'"
    TEMPTY_TAG_SINGLE   = 4
    stringConstants(4)  = "empty formatting tag"
    TEMPTY_TAG_MULTIPLE = 5
    stringConstants(5)  = "several empty formatting tag"
    TBAD_COLOR          = 6
    stringConstants(6)  = "bad color"
    TBAD_GRADIENT_POINT = 7
    stringConstants(7)  = "bad gradient point"
    TBADSHORT_TAG       = 8
    stringConstants(8)  = "bad short tag"
}
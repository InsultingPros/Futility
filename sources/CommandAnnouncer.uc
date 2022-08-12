/**
 *      Simple class to simplify announcements of changes made by Futility's
 *  commands. Allows to announnce different messages to self, target and others;
 *  changing them up when self coincides with target.
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
class CommandAnnouncer extends AcediaObject;

/**
 *  # `CommandAnnouncer`
 *
 *      Simple class to simplify announcements of changes made by Futility's
 *  commands. Allows to announnce different messages to self, target and others;
 *  changing them up when self coincides with target.
 *      Technically only for reporting successes, since failures are only
 *  reported to the instigator and are, therefore, simple. But for the sake of
 *  consistency, every report can be placed here.
 *
 *  ## Usage
 *
 *  There is supposed to be a separate announcer class for every command class,
 *  so there's two steps to setting one up: creating new class and putting it
 *  to proper use.
 *
 *  ### Creating new `CommandAnnouncer` class
 *
 *  Step by step the process is:
 *      1. Declare a new class, extending `CommandAnnouncer`;
 *      2. Declare iinside `AnnouncementVariations` field variables for every
 *          announcement;
 *      3. Declare a `Finalizer()` and place a `FreeVariations(...);` line for
 *          each announcement variable inside. Don't forget to later also make
 *          a `super.Finalizer();` call;
 *      4. For every announcement make a separate method that accepts values to
 *          be included in that announcement as arguments.
 *      5. Inside that method check whether corresponding announcement variable
 *          was already initialized (`initialized` field in side
 *          `AnnouncementVariations` struct) and otherwise initialize all
 *          contained `TextTemplate`s.
 *      6. Fill every template with passed arguments ("instigator" and "target"
 *          arguments are auto-filled later). For that you can use auxiliary
 *          method `MakeArray()`, e.g.
 *          ```unrealscript
 *          local int                   i;
 *          local array<TextTemplate>   templates;
 *          // ...
 *          templates = MakeArray(gainedDosh);
 *          for (i = 0; i < templates.length; i += 1) {
 *              templates[i].Reset().ArgInt(doshAmount);
 *          }
 *          ```
 *      7. Make a `MakeAnnouncement()`, passing it `AnnouncementVariations` that
 *          you've just (initialized and) filled with arguments.
 *
 *  ### Using created `CommandAnnouncer` class
 *
 *      Simply allocate variable of that class, make a `Setup()` call inside
 *  `Executed()` and `ExecutedFor()` (only necessary to do in the one you are
 *  using).
 *      Since it is way more efficient to only allocate such variable once
 *  (avoiding creating templates every time), it is recommended that you create
 *  it inside `BuildData()` call and remember that instance in a field variable.
 *  You then simply need to declare command's finalizer to deallocate it.
 *  Just don't forget to call `super.Finalizer()` as well.
 */

var private EPlayer         instigator, target;
var private int             instigatorLifeVersion, targetLifeVersion;
var private ConsoleWriter   publicConsole;
var private int             publicConsoleLifeVersion;

var private MutableText     instigatorName, targetName;

struct AnnouncementVariations
{
    var public bool         initialized;
    //  `toSelf...`     == command's instigator is targeting himself/herself;
    //  `toOther...`    == command's instigator is targeting somebody else;
    //  `...report`     == message is for a report to command's instigator;
    //  `...private`    == message is for a report to command's target;
    //  `...public`     == message is for a report to eveyone who isn't
    //                      an instigator or a target.
    var public TextTemplate toSelfReport;
    var public TextTemplate toSelfPublic;
    var public TextTemplate toOtherReport;
    var public TextTemplate toOtherPrivate;
    var public TextTemplate toOtherPublic;
};

protected function Finalizer()
{
    instigator      = none;
    target          = none;
    publicConsole   = none;
    _.memory.Free(instigatorName);
    _.memory.Free(targetName);
    instigatorName  = none;
    targetName      = none;
}

/**
 *  Prepares caller `CommandAnnouncer` to make announcements about
 *  `newInstigator` player affecting `newTarget` player.
 *
 *  @param  newTarget           Player that is targeted by the command.
 *  @param  newInstigator       Player that is calling the command, can be
 *      the same as `newTarget`.
 *  @param  newPublicConsole    Console instance to announce command's action to
 *      other (directly unaffected) players.
 */
public final function Setup(
    EPlayer         newTarget,
    EPlayer         newInstigator,
    ConsoleWriter   newPublicConsole)
{
    target = none;
    _.memory.Free(targetName);
    targetName = none;
    if (newTarget != none && newTarget.IsAllocated())
    {
        target = newTarget;
        targetLifeVersion = newTarget.GetLifeVersion();
        targetName = target
            .GetName()
            .IntoMutableText()
            .ChangeDefaultColor(_.color.LightGray);
    }
    instigator = none;
    _.memory.Free(instigatorName);
    instigatorName = none;
    if (newInstigator != none && newInstigator.IsAllocated())
    {
        instigator = newInstigator;
        instigatorLifeVersion = newInstigator.GetLifeVersion();
        instigatorName = instigator
            .GetName()
            .IntoMutableText()
            .ChangeDefaultColor(_.color.LightGray);
    }
    publicConsole = none;
    if (newPublicConsole != none && newPublicConsole.IsAllocated())
    {
        publicConsole = newPublicConsole;
        publicConsoleLifeVersion = newPublicConsole.GetLifeVersion();
    }
}

/**
 *  Makes appropriate announcements from `variations` to appropriate targets.
 *
 *  @param  variations  Struct with announcement templates to make.
 */
protected final function MakeAnnouncement(AnnouncementVariations variations)
{
    local ConsoleWriter instigatorConsole, targetConsole;

    if (!variations.initialized)    return;
    if (!ValidateClasses())         return;

    instigatorConsole   = _.console.For(instigator);
    targetConsole       = _.console.For(target);
    if (target == none || instigator.SameAs(target))
    {
        //  If instigator is targeting himself, then there is no need for
        //  a separate announcement to target
        AnnounceTemplate(instigatorConsole, variations.toSelfReport);
        AnnounceTemplate(publicConsole, variations.toSelfPublic);
    }
    else
    {
        //  Otherwise report to three different targets
        AnnounceTemplate(instigatorConsole, variations.toOtherReport);
        AnnounceTemplate(targetConsole, variations.toOtherPrivate);
        AnnounceTemplate(publicConsole, variations.toOtherPublic);
    }
}

/**
 *  Auxiliary method to free all objects inside given `AnnouncementVariations`
 *  struct.
 *
 *  @param  variations  Struct, whos contained objects methodf should free.
 */
protected final function FreeVariations(out AnnouncementVariations variations)
{
    _.memory.Free(variations.toSelfReport);
    _.memory.Free(variations.toSelfPublic);
    _.memory.Free(variations.toOtherReport);
    _.memory.Free(variations.toOtherPrivate);
    _.memory.Free(variations.toOtherPublic);
    variations.toSelfReport     = none;
    variations.toSelfPublic     = none;
    variations.toOtherReport    = none;
    variations.toOtherPrivate   = none;
    variations.toOtherPublic    = none;
    variations.initialized      = false;
}

/**
 *  Auxiliary method to put all `TextTemplate`s inside `variations` into
 *  an array that can then be easily iterated over.
 */
protected final function array<TextTemplate> MakeArray(
    AnnouncementVariations variations)
{
    local array<TextTemplate> result;

    if (variations.toSelfReport != none) {
        result[result.length] = variations.toSelfReport;
    }
    if (variations.toSelfPublic != none) {
        result[result.length] = variations.toSelfPublic;
    }
    if (variations.toOtherReport != none) {
        result[result.length] = variations.toOtherReport;
    }
    if (variations.toOtherPrivate != none) {
        result[result.length] = variations.toOtherPrivate;
    }
    if (variations.toOtherPublic != none) {
        result[result.length] = variations.toOtherPublic;
    }
    return result;
}

private final function bool ValidateClasses()
{
    if (instigator == none)                                     return false;
    if (publicConsole == none)                                  return false;
    if (instigator.GetLifeVersion() != instigatorLifeVersion)   return false;
    if (!instigator.IsExistent())                               return false;

    if (target != none)
    {
        if (    target.GetLifeVersion() != targetLifeVersion
            ||  !target.IsExistent())
        {
            target = none;
        }
    }
    if (publicConsole.GetLifeVersion() != publicConsoleLifeVersion) {
        return false;
    }
    return true;
}

private final function AnnounceTemplate(
    ConsoleWriter   writer,
    TextTemplate    template)
{
    local MutableText result;

    if (writer == none)             return;
    if (template == none)           return;
    if (!template.IsInitialized())  return;

    template
        .TextArg(P("instigator"), instigatorName)
        .TextArg(P("target"), targetName);
    result = template.CollectFormattedM();
    writer.Write(result).Flush();
    _.memory.Free(result);
}

defaultproperties
{
}
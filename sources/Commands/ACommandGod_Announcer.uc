/**
 *      Announcer for `ACommandGod`.
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
class ACommandGod_Announcer extends CommandAnnouncer
    dependson(ACommandGod);

var private AnnouncementVariations godStatus, newGod, removeGod, sameGod;
var private AnnouncementVariations changedGod, wasNotGod;

protected function Finalizer()
{
    FreeVariations(godStatus);
    FreeVariations(newGod);
    FreeVariations(removeGod);
    FreeVariations(sameGod);
    FreeVariations(changedGod);
    FreeVariations(wasNotGod);
    super.Finalizer();
}

public final function AnnounceGodStatus(ACommandGod.GodStatus status)
{
    local int                   i;
    local MutableText           statusAsText;
    local array<TextTemplate>   templates;

    if (!godStatus.initialized)
    {
        godStatus.initialized = true;
        godStatus.toSelfReport = _.text.MakeTemplate_S(
            "You're %1");
        godStatus.toOtherReport = _.text.MakeTemplate_S(
            "%%target%% is %1");
    }
    statusAsText = DisplayStatus(status);
    templates = MakeArray(godStatus);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().Arg(statusAsText);
    }
    _.memory.Free(statusAsText);
    MakeAnnouncement(godStatus);
}

public final function AnnounceNewGod(ACommandGod.GodStatus status)
{
    local int                   i;
    local MutableText           statusAsText;
    local array<TextTemplate>   templates;

    if (!newGod.initialized)
    {
        newGod.initialized = true;
        newGod.toSelfReport = _.text.MakeTemplate_S(
            "You {$TextPositive made} yourself %1");
        newGod.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextPositive made} themselves %1");
        newGod.toOtherReport = _.text.MakeTemplate_S(
            "You {$TextPositive made} %%target%% %1");
        newGod.toOtherPrivate = _.text.MakeTemplate_S(
            "%%instigator%% {$TextPositive made} you %1");
        newGod.toOtherPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextPositive made} %%target%% %1");
    }
    statusAsText = DisplayStatus(status);
    templates = MakeArray(newGod);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().Arg(statusAsText);
    }
    _.memory.Free(statusAsText);
    MakeAnnouncement(newGod);
}

public final function AnnounceRemoveGod(ACommandGod.GodStatus status)
{
    local int                   i;
    local MutableText           statusAsText;
    local array<TextTemplate>   templates;

    if (!removeGod.initialized)
    {
        removeGod.initialized = true;
        removeGod.toSelfReport = _.text.MakeTemplate_S(
            "You, %1, {$TextNegative became} a mere {$TextNegative mortal}");
        removeGod.toSelfPublic = _.text.MakeTemplate_S(
            "%1 %%instigator%% {$TextNegative made} themselves a mere"
            @ "{$TextNegative mortal}");
        removeGod.toOtherReport = _.text.MakeTemplate_S(
            "%1 %%target%% was {$TextNegative made} a mere"
            @ "{$TextNegative mortal} by you");
        removeGod.toOtherPrivate = _.text.MakeTemplate_S(
            "You, %1, was {$TextNegative made} a mere {$TextNegative mortal}"
            @ "by %%instigator%%");
        removeGod.toOtherPublic = _.text.MakeTemplate_S(
            "%1 %%target%% was {$TextNegative made} a mere"
            @ "{$TextNegative mortal} by %%instigator%%");
    }
    statusAsText = DisplayStatus(status);
    templates = MakeArray(removeGod);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().Arg(statusAsText);
    }
    _.memory.Free(statusAsText);
    MakeAnnouncement(removeGod);
}

public final function AnnounceSameGod(ACommandGod.GodStatus status)
{
    local int                   i;
    local MutableText           statusAsText;
    local array<TextTemplate>   templates;

    if (!sameGod.initialized)
    {
        sameGod.initialized = true;
        sameGod.toSelfReport = _.text.MakeTemplate_S(
            "You are already %1");
        sameGod.toOtherReport = _.text.MakeTemplate_S(
            "%%target%% is already %1");
    }
    statusAsText = DisplayStatus(status);
    templates = MakeArray(sameGod);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().Arg(statusAsText);
    }
    _.memory.Free(statusAsText);
    MakeAnnouncement(sameGod);
}

public final function AnnounceChangedGod(
    ACommandGod.GodStatus oldStatus,
    ACommandGod.GodStatus newStatus)
{
    local int                   i;
    local MutableText           oldStatusAsText, newStatusAsText;
    local array<TextTemplate>   templates;

    if (!changedGod.initialized)
    {
        changedGod.initialized = true;
        changedGod.toSelfReport = _.text.MakeTemplate_S(
            "You, %1, {$TextPositive made} yourself %2");
        changedGod.toSelfPublic = _.text.MakeTemplate_S(
            "%1 %%instigator%% {$TextPositive made} themselves %2");
        changedGod.toOtherReport = _.text.MakeTemplate_S(
            "You {$TextPositive made} %1 %%target%% into %1");
        changedGod.toOtherPrivate = _.text.MakeTemplate_S(
            "%%instigator%% {$TextPositive made} you, %1, into %2");
        changedGod.toOtherPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextPositive made} %1 %%target%% into %2");
    }
    oldStatusAsText = DisplayStatus(oldStatus);
    newStatusAsText = DisplayStatus(newStatus);
    templates = MakeArray(changedGod);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().Arg(oldStatusAsText).Arg(newStatusAsText);
    }
    _.memory.Free(oldStatusAsText);
    _.memory.Free(newStatusAsText);
    MakeAnnouncement(changedGod);
}

public final function AnnounceWasNotGod()
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!sameGod.initialized)
    {
        sameGod.initialized = true;
        sameGod.toSelfReport = _.text.MakeTemplate_S(
            "You are already a mere {$TextNegative mortal}");
        sameGod.toOtherReport = _.text.MakeTemplate_S(
            "%%target%% is already a mere {$TextNegative mortal}");
    }
    templates = MakeArray(sameGod);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset();
    }
    MakeAnnouncement(sameGod);
}

private final function MutableText DisplayStatus(ACommandGod.GodStatus status)
{
    local MutableText builder;

    builder = _.text.Empty();
    if (status.target == none)
    {
        builder.Append(F("a mere {$TextNegative mortal}"));
        return builder;
    }
    if (status.unmovable) {
        builder.Append(F("an {$TextPositive unmovable}, "));
    }
    else {
        builder.Append(F("a {$TextNeutral simple}, "));
    }
    if (status.demigod) {
        builder.Append(F("immortal {$TextNeutral demigod}"));
    }
    else {
        builder.Append(F("invincible {$TextPositive god}"));
    }
    return builder;
}

defaultproperties
{
}
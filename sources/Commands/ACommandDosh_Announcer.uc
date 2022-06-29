/**
 *      Announcer for `ACommandDosh`.
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
class ACommandDosh_Announcer extends CommandAnnouncer;

var private AnnouncementVariations gainedDosh, lostDosh;

protected function Finalizer()
{
    FreeVariations(gainedDosh);
    FreeVariations(lostDosh);
    super.Finalizer();
}

public final function AnnounceGainedDosh(int doshAmount)
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!gainedDosh.initialized)
    {
        gainedDosh.initialized = true;
        gainedDosh.toSelfReport = _.text.MakeTemplate_S(
            "You {$TextPositive gave} yourself {$TypeNumber %1} do$h!");
        gainedDosh.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextPositive gave} themselves {$TypeNumber %1}"
            @ "do$h!");
        gainedDosh.toOtherReport = _.text.MakeTemplate_S(
            "You {$TextPositive gave} %%target%% {$TypeNumber %1} do$h!");
        gainedDosh.toOtherPrivate = _.text.MakeTemplate_S(
            "%%instigator%% {$TextPositive gave} you {$TypeNumber %1} do$h!");
        gainedDosh.toOtherPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextPositive gave} %%target%% {$TypeNumber %1}"
            @ "do$h!");
    }
    templates = MakeArray(gainedDosh);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().ArgInt(doshAmount);
    }
    MakeAnnouncement(gainedDosh);
}

public final function AnnounceLostDosh(int doshAmount)
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!lostDosh.initialized)
    {
        lostDosh.initialized = true;
        lostDosh.toSelfReport = _.text.MakeTemplate_S(
            "You {$TextNegative took} {$TypeNumber %1} do$h from"
            @ "yourself!");
        lostDosh.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextNegative took} {$TypeNumber %1} do$h from"
            @ "themselves!");
        lostDosh.toOtherReport = _.text.MakeTemplate_S(
            "You {$TextNegative took} {$TypeNumber %1} do$h from"
            @ "%%target%%!");
        lostDosh.toOtherPrivate = _.text.MakeTemplate_S(
            "%%instigator%% {$TextNegative took} {$TypeNumber %1} do$h from"
            @ "you!");
        lostDosh.toOtherPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextNegative took} {$TypeNumber %1} do$h from"
            @ "%%target%%!");
    }
    templates = MakeArray(lostDosh);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().ArgInt(doshAmount);
    }
    MakeAnnouncement(lostDosh);
}

defaultproperties
{
}
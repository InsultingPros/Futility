/**
 *      Announcer for `ACommandSpawn`.
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
class ACommandSpawn_Announcer extends CommandAnnouncer;

var private AnnouncementVariations spawned, spawningFailed, failedTrace;

protected function Finalizer()
{
    FreeVariations(spawned);
    FreeVariations(spawningFailed);
    FreeVariations(failedTrace);
    super.Finalizer();
}

public final function AnnounceSpawned(BaseText template)
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!spawned.initialized)
    {
        spawned.initialized = true;
        spawned.toSelfReport = _.text.MakeTemplate_S(
            "You {$TextPositive spawned} {$TextEmphasis %1}!");
        spawned.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextNeutral spawned} {$TextEmphasis %1}!");
    }
    templates = MakeArray(spawned);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().Arg(template);
    }
    MakeAnnouncement(spawned);
}

public final function AnnounceSpawningFailed(BaseText template)
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!spawningFailed.initialized)
    {
        spawningFailed.initialized = true;
        spawningFailed.toSelfReport = _.text.MakeTemplate_S(
            "{$TextFailure Couldn't spawn} {$TextEmphasis %1}!");
    }
    templates = MakeArray(spawningFailed);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().Arg(template);
    }
    MakeAnnouncement(spawningFailed);
}

public final function AnnounceFailedTrace()
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!failedTrace.initialized)
    {
        failedTrace.initialized = true;
        failedTrace.toSelfReport = _.text.MakeTemplate_S(
            "{$TextFailure Failed} to trace spawn point");
    }
    templates = MakeArray(failedTrace);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset();
    }
    MakeAnnouncement(failedTrace);
}

defaultproperties
{
}
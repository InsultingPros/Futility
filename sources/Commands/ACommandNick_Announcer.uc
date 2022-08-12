/**
 *      Announcer for `ACommandNick`.
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
class ACommandNick_Announcer extends CommandAnnouncer;

var private AnnouncementVariations changedNickname, changedAlteredNickname;

protected function Finalizer()
{
    FreeVariations(changedNickname);
    FreeVariations(changedAlteredNickname);
    super.Finalizer();
}

public final function AnnounceChangedNickname(BaseText newNickname)
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!changedNickname.initialized)
    {
        changedNickname.initialized = true;
        changedNickname.toSelfReport = _.text.MakeTemplate_S(
            "Your nickname {$TextNeutral changed} to \"%1\"");
        changedNickname.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextNeutral changed} their own nickname to"
            @ "\"%1\"");
        changedNickname.toOtherReport = _.text.MakeTemplate_S(
            "Nickname for %%target%% {$TextNeutral changed} to"
            @ "\"%1\"");
        changedNickname.toOtherPrivate = _.text.MakeTemplate_S(
            "%%instigator%% {$TextNeutral changed} your nickname to \"%1\"");
        changedNickname.toOtherPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextNeutral changed} nickname for player"
            @ "%%target%% to \"%1\"");
    }
    templates = MakeArray(changedNickname);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().Arg(newNickname);
    }
    MakeAnnouncement(changedNickname);
}

public final function AnnounceChangedAlteredNickname(
    BaseText newNickname,
    BaseText alteredVersion)
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!changedAlteredNickname.initialized)
    {
        changedAlteredNickname.initialized = true;
        changedAlteredNickname.toSelfReport = _.text.MakeTemplate_S(
            "Your nickname was {$TextNeutral changed} to \"%1\", but then"
            @ "got altered by the game into \"%2\"");
        changedAlteredNickname.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% has {$TextNeutral changed} their own nickname to"
            @ "\"%1\", but it was altered by the game into \"%2\"");
        changedAlteredNickname.toOtherReport = _.text.MakeTemplate_S(
            "Nickname for %%target%% was {$TextNeutral changed} to"
            @ "\"%1\", but then got altered by the game into \"%2\"");
        changedAlteredNickname.toOtherPrivate = _.text.MakeTemplate_S(
            "%%instigator%% has {$TextNeutral changed} your nickname to \"%1\","
            @ "but then it got altered by the game into \"%2\"");
        changedAlteredNickname.toOtherPublic = _.text.MakeTemplate_S(
            "%%instigator%% has {$TextNeutral changed} nickname for player"
            @ "%%target%% to \"%1\", but then it got altered by the game"
            @ "into \"%2\"");
    }
    templates = MakeArray(changedAlteredNickname);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().Arg(newNickname).Arg(alteredVersion);
    }
    MakeAnnouncement(changedAlteredNickname);
}

defaultproperties
{
}
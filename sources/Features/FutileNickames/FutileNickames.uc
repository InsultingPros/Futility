/**
 *      Config object for `FutileNickames_Feature`.
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
class FutileNickames extends FeatureConfig
    perobjectconfig
    config(FutilityNicknames);

enum NicknameSpacesAction
{
    NSA_DoNothing,
    NSA_Trim,
    NSA_Simplify
};

enum NicknameColorPermissions
{
    NCP_ForbidColor,
    NCP_ForceTeamColor,
    NCP_ForceSingleColor,
    NCP_AllowAnyColor
};

var public config NicknameSpacesAction      spacesAction;
var public config NicknameColorPermissions  colorPermissions;
var public config bool                      replaceSpacesWithUnderscores;
var public config bool                      correctEmptyNicknames;
var public config int                       maxNicknameLength;
var public config array<string>             fallbackNickname;

protected function AssociativeArray ToData()
{
    local int               i;
    local DynamicArray      fallbackNicknamesData;
    local AssociativeArray  data;
    data = __().collections.EmptyAssociativeArray();
    data.SetItem(   P("spacesAction"),
                    _.text.FromString(string(spacesAction)), true);
    data.SetItem(   P("colorPermissions"),
                    _.text.FromString(string(colorPermissions)), true);
    data.SetBool(   P("replaceSpacesWithUnderscores"),
                    replaceSpacesWithUnderscores, true);
    data.SetBool(P("correctEmptyNicknames"), correctEmptyNicknames, true);
    data.SetInt(P("maxNicknameLength"), maxNicknameLength, true);
    fallbackNicknamesData = __().collections.EmptyDynamicArray();
    for (i = 0; i < fallbackNickname.length; i += 1)
    {
        fallbackNicknamesData.AddItem(
            __().text.FromFormattedString(fallbackNickname[i]), true);
    }
    data.SetItem(P("fallbackNickname"), fallbackNicknamesData, true);
    return data;
}

protected function FromData(AssociativeArray source)
{
    local int           i;
    local Text          nextNickName;
    local DynamicArray  fallbackNicknamesData;
    if (source == none) {
        return;
    }
    spacesAction = SpaceActionFromText(source.GetText(P("spacesAction")));
    colorPermissions = ColorPermissionsFromText(
        source.GetText(P("colorPermissions")));
    replaceSpacesWithUnderscores =
        source.GetBool(P("replaceSpacesWithUnderscores"), true);
    correctEmptyNicknames = source.GetBool(P("correctEmptyNicknames"), true);
    maxNicknameLength = source.GetInt(P("correctEmptyNicknames"), 20);
    fallbackNicknamesData = DynamicArray(source.GetItem(P("fallbackNickname")));
    if (fallbackNickname.length > 0) {
        fallbackNickname.length = 0;
    }
    for (i = 0; i < fallbackNicknamesData.GetLength(); i += 1)
    {
        nextNickName = fallbackNicknamesData.GetText(i);
        if (nextNickName != none) {
            fallbackNickname[i] = nextNickName.ToFormattedString();
        }
        else {
            fallbackNickname[i] = "";
        }
    }
}

private function NicknameSpacesAction SpaceActionFromText(Text action)
{
    if (action == none) {
        return NSA_DoNothing;
    }
    if (action.EndsWith(P("DoNothing"), SCASE_INSENSITIVE)) {
        return NSA_DoNothing;
    }
    if (action.EndsWith(P("Trim"), SCASE_INSENSITIVE)) {
        return NSA_Trim;
    }
    if (action.EndsWith(P("Simplify"), SCASE_INSENSITIVE)) {
        return NSA_Simplify;
    }
    return NSA_DoNothing;
}

private function NicknameColorPermissions ColorPermissionsFromText(
    Text permissions)
{
    if (permissions == none) {
        return NCP_ForbidColor;
    }
    if (permissions.EndsWith(P("ForbidColor"), SCASE_INSENSITIVE)) {
        return NCP_ForbidColor;
    }
    if (permissions.EndsWith(P("TeamColor"), SCASE_INSENSITIVE)) {
        return NCP_ForceTeamColor;
    }
    if (permissions.EndsWith(P("SingleColor"), SCASE_INSENSITIVE)) {
        return NCP_ForceSingleColor;
    }
    if (permissions.EndsWith(P("AllowAnyColor"), SCASE_INSENSITIVE)) {
        return NCP_AllowAnyColor;
    }
    return NCP_ForbidColor;
}

protected function DefaultIt()
{
    spacesAction        = NSA_DoNothing;
    colorPermissions    = NCP_ForbidColor;
    replaceSpacesWithUnderscores    = true;
    correctEmptyNicknames           = true;
    maxNicknameLength               = 20;
    if (fallbackNickname.length > 0) {
        fallbackNickname.length = 0;
    }
    fallbackNickname[0] = "Fresh Meat";
    fallbackNickname[1] = "Rotten Meat";
    fallbackNickname[2] = "Troll Meat";
    fallbackNickname[3] = "Rat Meat";
    fallbackNickname[4] = "Dog Meat";
    fallbackNickname[5] = "Elk Meat";
    fallbackNickname[6] = "Crab Meat";
    fallbackNickname[7] = "Boar Meat";
    fallbackNickname[8] = "Horker Meat";
    fallbackNickname[9] = "Bug Meat";
}

defaultproperties
{
    configName = "FutilityNicknames"
    spacesAction                    = NSA_DoNothing
    colorPermissions                = NCP_ForbidColor
    replaceSpacesWithUnderscores    = true
    correctEmptyNicknames           = true
    maxNicknameLength               = 20
    fallbackNickname(0) = "Fresh Meat"
    fallbackNickname(1) = "Rotten Meat"
    fallbackNickname(2) = "Troll Meat"
    fallbackNickname(3) = "Rat Meat"
    fallbackNickname(4) = "Dog Meat"
    fallbackNickname(5) = "Elk Meat"
    fallbackNickname(6) = "Crab Meat"
    fallbackNickname(7) = "Boar Meat"
    fallbackNickname(8) = "Horker Meat"
    fallbackNickname(9) = "Bug Meat"
}
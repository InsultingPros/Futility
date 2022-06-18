/**
 *      This feature allows to configure nickname limitations for the server.
 *      It allows you to customize vanilla limitations for nickname length and
 *  color with those of your own design. Enabling this feature overwrites
 *  default behaviour.
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
class FutilityNicknames_Feature extends Feature
    dependson(FutilityNicknames);

/**
 *  This feature's functionality is rather simple, but we will still break up
 *  what its various components are.
 *
 *      Fallback nicknames are picked at random from
 *  the `fallbackNicknames` array. This is done by copying that array into
 *  `unusedNicknames` and then picking and removing its random elements each
 *  time we need a fallback. Once `unusedNicknames` is empty - it is copied from
 *  `fallbackNicknames` once again, letting already used nicknames to be reused.
 *      `unusedNicknames` contains same references as `fallbackNicknames`,
 *  so they need to be separately deallocated and should also be forgotten once
 *  `fallbackNicknames` are deallocated`.
 *      This is implemented inside `PickNextFallback()` method.
 *
 *      Nickname changes are applied inside `CensorNickname()` method that uses
 *  several auxiliary methods to perform different stages of "censoring".
 *      Censoring is performed:
 *          1. On any player's name change
 *              (using `OnPlayerNameChanging()` signal, connected to
 *              `HandleNicknameChange()`);
 *          2. When new player logins (using `OnNewPlayer()` signal,
 *              conneted to `CensorOriginalNickname()`) to enforce our own
 *              handling of player's original nickname;
 *          3. When censoring is re-activated.
 *              In case all censoring options of this feature are disabled
 *              (checked by `IsAnyCensoringEnabled()`) - we do not attempt to
 *              catch any events or do anything at all.
 *              If settings change mid-execution, this feature might need to
 *              enable or disable censoring on-the-fly. To accomplish that we
 *              remember current status inside `censoringNicknames` boolean
 *              variable and enable/disable events if required by settings.
 *              So whenever we re-activate censoring we also need to update
 *              ("censor") current players' nicknames - a third occasion to
 *              call `CensorNickname()`, implemented inside
 *              `CensorCurrentPlayersNicknames()`.
 */

//  How to treat whitespace characters inside players' nicknames.
//      * `NSA_DoNothing` - does nothing, leaving whitespaces as they are;
//      * `NSA_Trim` - removes leading and trailing whitespaces for nicknames;
//      * `NSA_Simplify` - removes leading and trailing whitespaces
//          for nicknames, also reducing a sequence of whitespaces inside
//          nickname to a single space, e.g. "my   nick" becomes "my nick".
//  Default is `NSA_DoNothing`, same as on vanilla.
var private /*config*/ FutilityNicknames.NicknameSpacesAction spacesAction;

//  How to treat colored nicknames.
//      * `NCP_ForbidColor` - completely strips down any color from nicknames;
//      * `NCP_ForceTeamColor` - forces all nicknames to have player's current
//          team's color;
//      * `NCP_ForceSingleColor` - allows nickname to be painted with a single
//          color (sets nickname's color to that of the first character);
//      * `NCP_AllowAnyColor` - allows nickname to be colored in any way player
//          wants.
//  Default is `NCP_ForbidColor`, same as on vanilla.
var private /*config*/ FutilityNicknames.NicknameColorPermissions colorPermissions;

//      Set this to `true` if you wish to replace all whitespace characters with
//  underscores and `false` to leave them as is.
//      Default is `true`, same as on vanilla. However there is one difference:
//  Futility replaces all whitespace characters (including tabulations,
//  non-breaking spaces, etc.) instead of only ' '.
var private /*config*/ bool         replaceSpacesWithUnderscores;
//  Set this to `true` to remove single 'quotation marks' and `false` to
//  leave them. Default is `false`, same as on vanilla.
var private /*config*/ bool         removeSingleQuotationMarks;
//  Set this to `true` to remove dobule 'quotation marks' and `false` to
//  leave them. Default is `true`, same as on vanilla.
var private /*config*/ bool         removeDoubleQuotationMarks;

//  Max allowed nickname length. Negative values disable any length limits.
//
//  NOTE #1: `0` resets all nicknames to be empty and,
//      if `correctEmptyNicknames` is set to `true`, they will be replaced with
//      one of the fallback nicknames
//      (see `correctEmptyNicknames` and `fallbackNickname`).
//  NOTE #2: Because of how color swapping in vanilla Killing Floor works,
//      every color swap makes text count as being about 4 characters longer.
//      So if one uses too many colors in the nickname, for drawing functions
//      it will appear to be longer than it actually is and it *will* mess up
//      UI. Unless you are using custom HUD it is recommended to keep this value
//      at default `20` and forbid colored nicknames
//      (by setting `colorPermissions=NCP_ForbidColor`). Or to allow only one
//      color (by setting `colorPermissions=NCP_ForceSingleColor` or
//      `colorPermissions=NCP_ForceTeamColor`) and reducing `maxNicknameLength`
//      to `16` (20 characters - 4 for color swap).
//          If you want to increase the limit above that, you can also do your
//      own research by testing nicknames of various length on
//      screen resolutions you care about.
var private /*config*/ int          maxNicknameLength;

//  Should we replace empty player nicknames with a random fallback nickname
//  (defined in `fallbackNickname` array)?
var private /*config*/ bool         correctEmptyNicknames;
//  Array of fallback nicknames that will be used to replace any empty nicknames
//  if `correctEmptyNicknames` is set to `true`.
var private /*config*/ array<Text>  fallbackNickname;

//  Guaranteed order of applying changes (only chosen ones) is as following:
//      1. Trim/simplify spaces;
//      2. Remove single and double quotation marks;
//      3. Enforce max limit of nickname's length;
//      4. Replace empty nickname with fallback nickname (no further changes
//          will be applied to fallback nickname in that case);
//      5. Enforce color limitation;
//      6. Replace remaining whitespaces with underscores.
//
//  NOTE #1: as follows from the instruction described above, no changes will
//      ever be applied to fallback nicknames (unless player's nickname
//      coincides with one by pure accident).
//  NOTE #2: whitespaces inside steam nicknames are converted into underscores
//      before they are passed into the game and this is a change Futility
//      cannot currently abort.
//      Therefore all changes relevant to whitespaces inside nicknames will only
//      be applied to in-game changes.

//  Nicknames from `fallbackNickname` that can still be picked in
//  the current rotation.
var private array<Text> unusedNicknames;
//      Are we currently censoring nicknames?
//      Set to `false` if none of the feature's options require
//  any action (censoring) and, therefore, we do not listen to any signals.
var private bool        censoringNicknames;

var private const int CODEPOINT_UNDERSCORE;

protected function OnDisabled()
{
    _.memory.FreeMany(fallbackNickname);
    //  Free this `Text` data - it will be refilled with `SwapConfig()`
    //  if this feature is ever reenabled
    if (fallbackNickname.length > 0)
    {
        _.memory.FreeMany(fallbackNickname);
        fallbackNickname.length = 0;
        unusedNicknames.length  = 0;
    }
    if (censoringNicknames)
    {
        censoringNicknames = false;
        _.players.OnPlayerNameChanging(self).Disconnect();
        _.players.OnNewPlayer(self).Disconnect();
    }
}

protected function SwapConfig(FeatureConfig config)
{
    local bool              configRequiresCensoring;
    local FutilityNicknames newConfig;
    newConfig = FutilityNicknames(config);
    if (newConfig == none) {
        return;
    }
    replaceSpacesWithUnderscores    = newConfig.replaceSpacesWithUnderscores;
    removeSingleQuotationMarks      = newConfig.removeSingleQuotationMarks;
    removeDoubleQuotationMarks      = newConfig.removeDoubleQuotationMarks;
    correctEmptyNicknames           = newConfig.correctEmptyNicknames;
    spacesAction                    = newConfig.spacesAction;
    colorPermissions                = newConfig.colorPermissions;
    maxNicknameLength               = newConfig.maxNicknameLength;
    configRequiresCensoring         = IsAnyCensoringEnabled();
    //  Enable or disable censoring if `IsAnyCensoringEnabled()`'s response
    //  has changed.
    if (!censoringNicknames && configRequiresCensoring)
    {
        censoringNicknames = true;
        //  Do this before adding event handler to
        //  avoid censoring nicknames second time
        CensorCurrentPlayersNicknames();
        _.players.OnPlayerNameChanging(self).connect = HandleNicknameChange;
        _.players.OnNewPlayer(self).connect = CensorOriginalNickname;
    }
    if (censoringNicknames && !configRequiresCensoring)
    {
        censoringNicknames = false;
        _.players.OnPlayerNameChanging(self).Disconnect();
        _.players.OnNewPlayer(self).Disconnect();
    }
    SwapFallbackNicknames(newConfig);
}

private function Text PickNextFallback()
{
    local int   pickedIndex;
    local Text  result;
    if (fallbackNickname.length <= 0)
    {
        //  Just in case this feature is really misconfigured
        return P("Fresh Meat").Copy();
    }
    if (unusedNicknames.length <= 0) {
        unusedNicknames = fallbackNickname;
    }
    //  Pick one nickname at random.
    //  `pickedIndex` will belong to [0; unusedNicknames.length - 1] segment.
    pickedIndex = Rand(unusedNicknames.length);
    result = unusedNicknames[pickedIndex].Copy();
    unusedNicknames.Remove(pickedIndex, 1);
    return result;
}

protected function SwapFallbackNicknames(FutilityNicknames newConfig)
{
    local int i;
    _.memory.FreeMany(fallbackNickname);
    if (fallbackNickname.length > 0) {
        fallbackNickname.length = 0;
    }
    for (i = 0; i < newConfig.fallbackNickname.length; i += 1)
    {
        fallbackNickname[i] =
            _.text.FromFormattedString(newConfig.fallbackNickname[i]);
    }
    unusedNicknames = fallbackNickname;
}

private function bool IsAnyCensoringEnabled()
{
    return (    replaceSpacesWithUnderscores
            ||  removeSingleQuotationMarks
            ||  removeDoubleQuotationMarks
            ||  correctEmptyNicknames
            ||  maxNicknameLength >= 0
            ||  colorPermissions != NCP_AllowAnyColor
            ||  spacesAction != NSA_DoNothing);
}

//  For nickname changes mid-game.
private function HandleNicknameChange(
    EPlayer     affectedPlayer,
    BaseText    oldName,
    MutableText newName)
{
    CensorNickname(newName, affectedPlayer);
}

//  For handling of player's original nicknames.
private function CensorOriginalNickname(EPlayer affectedPlayer)
{
    local Text originalNickname;
    if (affectedPlayer == none) {
        return;
    }
    originalNickname = affectedPlayer.GetOriginalName();
    //  This will automatically trigger `OnPlayerNameChanging()` signal and
    //  our `HandleNicknameChange()` handler.
    affectedPlayer.SetName(originalNickname);
    _.memory.Free(originalNickname);
}

//  For handling nicknames of players after censoring is re-activated by
//  config change.
private function CensorCurrentPlayersNicknames()
{
    local int               i;
    local Text              nextNickname;
    local MutableText       alteredNickname;
    local array<EPlayer>    currentPlayers;
    currentPlayers = _.players.GetAll();
    for (i = 0; i < currentPlayers.length; i += 1)
    {
        nextNickname    = currentPlayers[i].GetName();
        alteredNickname = nextNickname.MutableCopy();
        CensorNickname(alteredNickname, currentPlayers[i]);
        if (!alteredNickname.Compare(nextNickname)) {
            currentPlayers[i].SetName(alteredNickname);
        }
        _.memory.Free(alteredNickname);
        _.memory.Free(nextNickname);
    }
}

private function CensorNickname(MutableText nickname, EPlayer affectedPlayer)
{
    local Text                  fallback;
    local BaseText.Formatting   newFormatting;
    if (nickname == none)       return;
    if (affectedPlayer == none) return;

    if (spacesAction != NSA_DoNothing) {
        nickname.Simplify(spacesAction == NSA_Simplify);
    }
    if (removeSingleQuotationMarks) {
        nickname.Replace(P("'"), P(""));
    }
    if (removeDoubleQuotationMarks) {
        nickname.Replace(P("\""), P(""));
    }
    if (maxNicknameLength >= 0) {
        nickname.Remove(maxNicknameLength);
    }
    if (correctEmptyNicknames && nickname.IsEmpty())
    {
        fallback = PickNextFallback();
        nickname.Append(fallback);
        _.memory.Free(fallback);
        return;
    }
    if (colorPermissions != NCP_AllowAnyColor)
    {
        if (colorPermissions == NCP_ForceSingleColor) {
            newFormatting = nickname.GetCharacter(0).formatting;
        }
        else if (colorPermissions == NCP_ForceTeamColor)
        {
            newFormatting.isColored = true;
            newFormatting.color     = affectedPlayer.GetTeamColor();
        }
        //  `colorPermissions == NCP_ForbidColor`
        //  `newFormatting` is colorless by default
        nickname.ChangeFormatting(newFormatting);
    }
    if (replaceSpacesWithUnderscores) {
        ReplaceSpaces(nickname);
    }
}

//  Asusmes `nickname != none`.
private function ReplaceSpaces(MutableText nickname)
{
    local int                   i;
    local MutableText           nicknameCopy;
    local BaseText.Character    nextCharacter, underscoreCharacter;
    nicknameCopy = nickname.MutableCopy();
    nickname.Clear();
    underscoreCharacter =
        _.text.CharacterFromCodePoint(CODEPOINT_UNDERSCORE);
    for (i = 0; i < nicknameCopy.GetLength(); i += 1)
    {
        nextCharacter = nicknameCopy.GetCharacter(i);
        if (_.text.IsWhitespace(nextCharacter))
        {
            //  Replace character with underscore, leaving the formatting
            underscoreCharacter.formatting = nextCharacter.formatting;
            nextCharacter = underscoreCharacter;
        }
        nickname.AppendCharacter(nextCharacter);
    }
    _.memory.Free(nicknameCopy);
}

defaultproperties
{
    configClass = class'FutilityNicknames'
    CODEPOINT_UNDERSCORE = 95 // '_'
}
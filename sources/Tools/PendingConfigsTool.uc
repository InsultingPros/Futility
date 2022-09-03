/**
 *      Auxiliary object for `ACommandFeature` to help with managing pending
 *  configs for `Feature`s. Pending configs are `HashTable`s with config data
 *  that are yet to be applied to configs and `Feature`s. They allow users to
 *  make several changes to the data before actually applying changes to
 *  the gameplay.
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
class PendingConfigsTool extends AcediaObject;

/**
 *      This tool works by selecting feature (by class) and config (by `Text`
 *  name) on which it will operate with `SelectConfig()` method and then
 *  invoking the rest of its methods on these selections.
 *     There are some expections (`HasPendingConfigFor()` method) that
 *  explicitly take these values as parameters.
 *      This tool is supposed to be created once for the "feature" command and
 *  have its `SelectConfig()` called each execution with user-specified
 *  parameters.
 */
var private class<Feature>  selectedFeatureClass;
var private Text            selectedConfigName;

//  Possible errors that might occur when working with pending configs
enum PendingConfigToolResult
{
    //  No error
    PCTE_None,
    //  Pending version of specified config does not exist
    PCTE_ConfigMissing,
    //  JSON object (`HashTable`) was expected as a parameter for the operation,
    //  but something else was given
    PCTE_ExpectedObject,
    //  Specified JSON pointer points an non-existent location
    PCTE_BadPointer
};

struct PendingConfigs
{
    var class<Feature>  featureClass;
    var HashTable       pendingSaves;
};
var private array<PendingConfigs> featurePendingEdits;

protected function Finalizer()
{
    local int i;

    for (i = 0; i < featurePendingEdits.length; i ++) {
        _.memory.Free(featurePendingEdits[i].pendingSaves);
    }
    featurePendingEdits.length = 0;
}

/**
 *  Selects feature and config to perform all future operations on.
 *
 *  @param  featureClass    Class of the feature for which to edit pending
 *      configs.
 *  @param  configName      Name of the pending config that caller tool will
 *      work with.
 */
public final function SelectConfig(
    class<Feature>  featureClass,
    BaseText        configName)
{
    _.memory.Free(selectedConfigName);
    selectedFeatureClass    = featureClass;
    selectedConfigName      = none;
    if (configName != none) {
        selectedConfigName = configName.LowerCopy();
    }
}

/**
 *      Checks wither caller tool has recorded pending config named `configName`
 *  for `Feature` defined by class `featureClass`.
 *      This method does no checks regarding existence of an actual config for
 *  the specified `Feature` - it only checks whether caller tool has pending
 *  version.
 *
 *  @param  featureClass    Class of the `Feature` to check for pending config.
 *  @param  configName      Name of the config to check for existence of its
 *      pending version.
 *  @return `true` if specified pending config exists and `false` otherwise.
 */
public function bool HasPendingConfigFor(
    class<Feature>  featureClass,
    BaseText        configName)
{
    local int   i;
    local bool  result;
    local Text  lowerCaseConfigName;

    if (featureClass == none)   return false;
    if (configName == none)     return false;

    for (i = 0; i < featurePendingEdits.length; i ++)
    {
        if (featurePendingEdits[i].featureClass == featureClass)
        {
            lowerCaseConfigName = configName.LowerCopy();
            result = featurePendingEdits[i].pendingSaves
                .HasKey(lowerCaseConfigName);
            lowerCaseConfigName.FreeSelf();
            return result;
        }
    }
    return false;
}

/**
 *  Returns data recorded for the selected pending config inside caller tool.
 *
 *  @param  createIfMissing Method only returns data of the pending version of
 *      the config and if selected config does not yet have a pending version,
 *      it will, by default, return `none`. This parameter allows this method to
 *      create a pending config, based on current config with selected name
 *      (if it exists).
 *  @return Data recorded for the selected pending config. If selected config
 *      does not have a pending version, `createIfMissing` is set to `false`
 *      or not even current config with selected name exists - method returns
 *      `none`.
 */
public function HashTable GetPendingConfigData(optional bool createIfMissing)
{
    local int               editsIndex;
    local HashTable         result;
    local PendingConfigs    newRecord;

    if (selectedConfigName == none) {
        return none;
    }
    editsIndex = GetPendingConfigDataIndex();
    if (editsIndex >= 0)
    {
        result = featurePendingEdits[editsIndex]
            .pendingSaves
            .GetHashTable(selectedConfigName);
        if (result != none) {
            return result;
        }
    }
    if (createIfMissing)
    {
        if (editsIndex < 0)
        {
            editsIndex = featurePendingEdits.length;
            newRecord.featureClass = selectedFeatureClass;
            newRecord.pendingSaves = _.collections.EmptyHashTable();
            featurePendingEdits[editsIndex] = newRecord;
        }
        result = GetCurrentConfigData();
        if (result != none)
        {
            featurePendingEdits[editsIndex]
                .pendingSaves
                .SetItem(selectedConfigName, result);
        }
    }
    return result;
}

/**
 *  Makes and edit to the config.
 *
 *  @param  pathToValue JSON path at which to make a change.
 *  @param  newValue    Value to record at the specified path.
 *  @return Result of the operation that reports any errors that have occured.
 *      Any changes are made iff result is `PCTE_None`.
 */
public function PendingConfigToolResult EditConfig(
    BaseText pathToValue,
    BaseText newValue)
{
    local HashTable                 pendingData;
    local JSONPointer               pointer;
    local Parser                    parser;
    local AcediaObject              newValueAsJSON;
    local PendingConfigToolResult   result;

    if (pathToValue == none) {
        return PCTE_BadPointer;
    }
    pendingData = GetPendingConfigData(true);
    if (pendingData == none) {
        return PCTE_ConfigMissing;
    }
    //  Get guaranteed not-`none` JSON value, treating it as JSON string
    //  if necessary
    parser = _.text.Parse(newValue);
    newValueAsJSON = _.json.ParseWith(parser);
    parser.FreeSelf();
    if (newValueAsJSON == none && newValue != none) {
        newValueAsJSON = newValue.Copy();
    }
    //  Set new data
    pointer = _.json.Pointer(pathToValue);
    result = SetItemByJSON(pendingData, pointer, newValueAsJSON);
    pointer.FreeSelf();
    pendingData.FreeSelf();
    _.memory.Free(newValueAsJSON);
    return result;
}

private function PendingConfigToolResult SetItemByJSON(
    HashTable       data,
    JSONPointer     pointer,
    AcediaObject    jsonValue)
{
    local Text                      containerIndex;
    local AcediaObject              container;
    local PendingConfigToolResult   result;

    if (pointer.IsEmpty())
    {
        if (HashTable(jsonValue) != none)
        {
            result = ChangePendingConfigData(HashTable(jsonValue));
            _.memory.Free(jsonValue);
            return result;
        }
        _.memory.Free(jsonValue);
        return PCTE_ExpectedObject;
    }
    //  Since `!pointer.IsEmpty()`, we are guaranteed to pop a valid value
    containerIndex  = pointer.Pop();
    container       = data.GetItemByJSON(pointer);
    if (container == none)
    {
        containerIndex.FreeSelf();
        return PCTE_BadPointer;
    }
    result = SetContainerItemByText(container, containerIndex, jsonValue);
    containerIndex.FreeSelf();
    container.FreeSelf();
    return result;
}

private function PendingConfigToolResult SetContainerItemByText(
    AcediaObject    container,
    BaseText        containerIndex,
    AcediaObject    jsonValue)
{
    local int       arrayIndex;
    local Parser    parser;
    local ArrayList arrayListContainer;
    local HashTable hashTableContainer;

    hashTableContainer = HashTable(container);
    arrayListContainer = ArrayList(container);
    if (hashTableContainer != none) {
        hashTableContainer.SetItem(containerIndex, jsonValue);
    }
    if (arrayListContainer != none)
    {
        parser = containerIndex.Parse();
        if (parser.MInteger(arrayIndex, 10).Ok())
        {
            arrayListContainer.SetItem(arrayIndex, jsonValue);
            parser.FreeSelf();
            return PCTE_None;
        }
        parser.FreeSelf();
        if (containerIndex.Compare(P("-"))) {
            arrayListContainer.AddItem(jsonValue);
        }
        else {
            return PCTE_BadPointer;
        }
    }
    return PCTE_None;
}

/**
 *  Removes selected pending config.
 *
 *  @return Result of the operation that reports any errors that have occured.
 *      Any changes are made iff result is `PCTE_None`.
 */
public final function PendingConfigToolResult RemoveConfig()
{
    local int       editIndex;
    local HashTable pendingSaves;

    editIndex = GetPendingConfigDataIndex();
    if (editIndex < 0)                              return PCTE_ConfigMissing;
    pendingSaves = featurePendingEdits[editIndex].pendingSaves;
    if (!pendingSaves.HasKey(selectedConfigName))   return PCTE_ConfigMissing;

    pendingSaves.RemoveItem(selectedConfigName);
    if (pendingSaves.GetLength() <= 0)
    {
        pendingSaves.FreeSelf();
        featurePendingEdits.Remove(editIndex, 1);
    }
    return PCTE_None;
}

private function int GetPendingConfigDataIndex()
{
    local int i;

    for (i = 0; i < featurePendingEdits.length; i ++)
    {
        if (featurePendingEdits[i].featureClass == selectedFeatureClass) {
            return i;
        }
    }
    return -1;
}

private function PendingConfigToolResult ChangePendingConfigData(
    HashTable newData)
{
    local int editsIndex;

    if (selectedConfigName == none) {
        return PCTE_None;
    }
    editsIndex = GetPendingConfigDataIndex();
    if (editsIndex < 0) {
        return PCTE_ConfigMissing;
    }
    featurePendingEdits[editsIndex].pendingSaves
        .SetItem(selectedConfigName, newData);
    return PCTE_None;
}

private function HashTable GetCurrentConfigData()
{
    return selectedFeatureClass.default.configClass.static
        .LoadData(selectedConfigName);
}

defaultproperties
{
}
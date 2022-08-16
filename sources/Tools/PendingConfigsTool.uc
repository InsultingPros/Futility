/**
 *      Auxiliary object for `ACommandFeature` to help with managing pending
 *  configs for `Feature`s. Pending configs are `HashTable`s with config data
 *  that are yet to be applied to configs and `Feature`s. They allow users to
 *  make several changes to the data before actually making changes to
 *  the gameplay code.
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

var private class<Feature>  selectedFeatureClass;
var private Text            selectedConfigName;

enum PendingConfigToolError
{
    PCTE_None,
    PCTE_ConfigMissing,
    PCTE_ExpectedObject,
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

public function PendingConfigToolError ChangeConfig(
    BaseText pathToValue,
    BaseText newValue)
{
    local HashTable                 pendingData;
    local JSONPointer               pointer;
    local Parser                    parser;
    local AcediaObject              newValueAsJSON;
    local PendingConfigToolError    result;

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

private function PendingConfigToolError SetItemByJSON(
    HashTable       data,
    JSONPointer     pointer,
    AcediaObject    jsonValue)
{
    local Text                      containerIndex;
    local AcediaObject              container;
    local PendingConfigToolError    result;

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

private function PendingConfigToolError SetContainerItemByText(
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

private function PendingConfigToolError ChangePendingConfigData(
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
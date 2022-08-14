/**
 *  Command for managing features.
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
class ACommandFeature extends Command;

//  TODO: autoconf, newconf, deleteconf, setconf

struct EditedConfigs
{
    var class<Feature>  featureClass;
    var HashTable       pendingSaves;
};
var private array<EditedConfigs> configEdits;

var private ACommandFeature_Announcer announcer;

protected function Finalizer()
{
    local int i;

    _.memory.Free(announcer);
    for (i = 0; i < configEdits.length; i ++) {
        _.memory.Free(configEdits[i].pendingSaves);
    }
    configEdits.length = 0;
    super.Finalizer();
}

protected function BuildData(CommandDataBuilder builder)
{
    builder.Name(P("feature")).Group(P("admin"))
        .Summary(P("Managing features."))
        .Describe(P("Command for displaying and enabling/disabling features."));
    builder.SubCommand(P("enable"))
        .ParamText(P("feature"))
        .OptionalParams()
        .ParamText(P("config"))
        .Describe(P("Enables specified <feature>."));
    builder.SubCommand(P("disable"))
        .ParamText(P("feature"))
        .Describe(P("Disables specified <feature>."));
    builder.SubCommand(P("showconf"))
        .ParamText(P("feature"))
        .ParamText(P("config"));
    builder.SubCommand(P("editconf"))
        .ParamText(P("feature"))
        .ParamText(P("config"))
        .ParamText(P("variable path"))
        .ParamRemainder(P("value"));
    announcer = ACommandFeature_Announcer(
        _.memory.Allocate(class'ACommandFeature_Announcer'));
}

protected function Executed(CallData arguments, EPlayer instigator)
{
    announcer.Setup(none, instigator, othersConsole);
    if (arguments.subCommandName.IsEmpty()) {
        ShowAllFeatures();
    }
    else if (arguments.subCommandName.Compare(P("enable")))
    {
        EnableFeature(
            arguments.parameters.GetText(P("feature")),
            arguments.parameters.GetText(P("config")));
    }
    else if (arguments.subCommandName.Compare(P("disable"))) {
        DisableFeature(arguments.parameters.GetText(P("feature")));
    }
    else if (arguments.subCommandName.Compare(P("showconf")))
    {
        ShowFeatureConfig(
            arguments.parameters.GetText(P("feature")),
            arguments.parameters.GetText(P("config")));
    }
    else if (arguments.subCommandName.Compare(P("editconf")))
    {
        EditFeatureConfig(
            arguments.parameters.GetText(P("feature")),
            arguments.parameters.GetText(P("config")),
            arguments.parameters.GetText(P("variable path")),
            arguments.parameters.GetText(P("value")));
    }
}

protected function EnableFeature(BaseText featureName, BaseText configParameter)
{
    local bool              wasEnabled;
    local Text              oldConfig, newConfig;
    local Feature           instance;
    local class<Feature>    featureClass;

    featureClass = LoadFeatureClass(featureName);
    if (featureClass == none) {
        return;
    }
    wasEnabled  = featureClass.static.IsEnabled();
    oldConfig   = featureClass.static.GetCurrentConfig();
    newConfig   = PickConfigBasedOnParameter(featureClass, configParameter);
    //  Already enabled with the same config!
    if (oldConfig != none && oldConfig.Compare(newConfig, SCASE_INSENSITIVE))
    {
        announcer.AnnounceFailedAlreadyEnabled(featureClass, newConfig);
        _.memory.Free(newConfig);
        _.memory.Free(oldConfig);
        return;
    }
    //  Try enabling and report the result
    instance = featureClass.static.EnableMe(newConfig);
    if (instance == none) {
        announcer.AnnounceFailedCannotEnableFeature(featureClass, newConfig);
    }
    else if (wasEnabled) {
        announcer.AnnounceSwappedConfig(featureClass, oldConfig, newConfig);
    }
    else {
        announcer.AnnounceEnabledFeature(featureClass, newConfig);
    }
    _.memory.Free(newConfig);
    _.memory.Free(oldConfig);
}

protected function DisableFeature(Text featureName)
{
    local class<Feature> featureClass;

    featureClass = LoadFeatureClass(featureName);
    if (featureClass == none) {
        return;
    }
    if (!featureClass.static.IsEnabled())
    {
        announcer.AnnounceFailedAlreadyDisabled(featureClass);
        return;
    }
    featureClass.static.DisableMe();
    //  It is possible that this command itself is destroyed after above command
    //  so do the check just in case
    if (IsAllocated()) {
        announcer.AnnounceDisabledFeature(featureClass);
    }
}

protected function ShowFeatureConfig(
    BaseText featureName,
    BaseText configParameter)
{
    local MutableText       dataAsJSON;
    local HashTable         currentData, pendingData;
    local class<Feature>    featureClass;

    featureClass = LoadFeatureClass(featureName);
    if (featureClass == none)       return;
    if (configParameter == none)    return;

    currentData = GetCurrentConfigData(featureClass, configParameter);
    if (currentData == none)
    {
        announcer.AnnounceFailedNoDataForConfig(featureClass, configParameter);
        return;
    }
    //  Display current data
    dataAsJSON = _.json.PrettyPrint(currentData);
    announcer.AnnounceCurrentConfig(featureClass, configParameter);
    callerConsole.Flush().WriteLine(dataAsJSON);
    _.memory.Free(dataAsJSON);
    //  Display pending data
    pendingData = GetPendingConfigData(featureClass, configParameter);
    if (pendingData != none)
    {
        dataAsJSON = _.json.PrettyPrint(pendingData);
        announcer.AnnouncePendingConfig(featureClass, configParameter);
        callerConsole.Flush().WriteLine(dataAsJSON);
        _.memory.Free(dataAsJSON);
    }
    _.memory.Free(pendingData);
    _.memory.Free(currentData);
}

protected function Text PickConfigBasedOnParameter(
    class<Feature>  featureClass,
    BaseText        configParameter)
{
    local Text                  resolvedConfig;
    local class<FeatureConfig>  configClass;

    if (featureClass == none) {
        return none;
    }
    configClass = featureClass.default.configClass;
    if (configClass == none)
    {
        announcer.AnnounceFailedNoConfigClass(featureClass);
        return none;
    }
    //  If config was specified - simply check that it exists
    if (configParameter != none)
    {
        if (configClass.static.Exists(configParameter)) {
            return configParameter.Copy();
        }
        announcer.AnnounceFailedConfigMissing(configParameter);
        return none;
    }
    //  If it wasn't specified - try auto config instead
    resolvedConfig = configClass.static.GetAutoEnabledConfig();
    if (resolvedConfig == none) {
        announcer.AnnounceFailedNoConfigProvided(featureClass);
    }
    return resolvedConfig;
}

protected function class<Feature> LoadFeatureClass(BaseText featureName)
{
    local Text              featureClassName;
    local class<Feature>    featureClass;
    if (featureName == none) {
        return none;
    }
    if (featureName.StartsWith(P("$"))) {
        featureClassName = _.alias.ResolveFeature(featureName, true);
    }
    else {
        featureClassName = featureName.Copy();
    }
    featureClass = class<Feature>(_.memory.LoadClass(featureClassName));
    if (featureClass == none) {
        announcer.AnnounceFailedToLoadFeatureClass(featureName);
    }
    _.memory.Free(featureClassName);
    return featureClass;
}

protected function ShowAllFeatures()
{
    local int                       i;
    local array< class<Feature> >   availableFeatures;
    availableFeatures = _.environment.GetAvailableFeatures();
    for (i = 0; i < availableFeatures.length; i ++) {
        ShowFeature(availableFeatures[i]);
    }
}

protected function ShowFeature(class<Feature> feature)
{
    local int                   i;
    local Text                  autoConfig;
    local MutableText           featureName, builder;
    local ListBuilder           configList;
    local array<Text>           availableConfigs;
    local class<FeatureConfig>  configClass;

    if (feature == none) {
        return;
    }
    configClass = feature.default.configClass;
    if (configClass != none) {
        availableConfigs = configClass.static.AvailableConfigs();
    }
    featureName = _.text
        .FromClassM(feature)
        .ChangeDefaultColor(_.color.TextEmphasis);
    builder = _.text.Empty();
    if (feature.static.IsEnabled()) {
        builder.Append(F("[  {$TextPositive enabled} ] "));
    }
    else {
        builder.Append(F("[ {$TextNegative disabled} ] "));
    }
    builder.Append(featureName);
    _.memory.Free(featureName);
    if (availableConfigs.length == 1) {
        builder.Append(P(" with config:"));
    }
    else if (availableConfigs.length > 1) {
        builder.Append(P(" with configs:"));
    }
    callerConsole.Write(builder);
    _.memory.Free(builder);
    configList = ListBuilder(_.memory.Allocate(class'ListBuilder'));
    autoConfig = configClass.static.GetAutoEnabledConfig();
    for (i = 0; i < availableConfigs.length; i += 1)
    {
        configList.Item(availableConfigs[i]);
        if (    autoConfig != none
            &&  autoConfig.Compare(availableConfigs[i], SCASE_INSENSITIVE))
        {
            configList.Comment(F("{$TextPositive auto enabled}"));
        }
    }
    builder = configList.GetMutable();
    callerConsole.WriteLine(builder);
    _.memory.FreeMany(availableConfigs);
    _.memory.Free(configList);
    _.memory.Free(autoConfig);
    _.memory.Free(builder);
}
//TODO: find where `null` spam is from
//TODO add failure color to fail announcements and good color to good ones - add them too!
protected function EditFeatureConfig(
    BaseText featureName,
    BaseText configParameter,
    BaseText pathToValue,
    BaseText newValue)
{
    local int               arrayIndex;
    local Text              topValue;
    local HashTable         pendingData;
    local JSONPointer       pointer;
    local Parser            parser;
    local AcediaObject      jsonValue, container;
    local class<Feature>    featureClass;

    featureClass = LoadFeatureClass(featureName);
    if (featureClass == none) {
        return;
    }
    pendingData = GetPendingConfigData(featureClass, configParameter, true);
    if (pendingData == none)
    {
        announcer.AnnounceFailedConfigMissing(configParameter);
        return;
    }
    //  Get guaranteed not-`none` JSON value
    parser = newValue.Parse();
    jsonValue = _.json.ParseWith(parser);
    parser.FreeSelf();
    if (jsonValue == none) {
        jsonValue = newValue.Copy();
    }
    //
    pointer = _.json.Pointer(pathToValue);
    if (pointer.IsEmpty())
    {
        if (jsonValue.class != class'HashTable') {
            announcer.AnnounceFailedExpectedObject();
        }
        else {
            ChangePendingConfigData(featureClass, configParameter, HashTable(jsonValue));
        }
        jsonValue.FreeSelf();
        return;
    }
    topValue = pointer.Pop();
    container = pendingData.GetItemByJSON(pointer);
    if (container == none)
    {
        announcer.AnnounceFailedBadPointer(featureClass, configParameter, pathToValue);
        pointer.FreeSelf();
        topValue.FreeSelf();
        return;
    }
    if (HashTable(container) != none) {
        HashTable(container).SetItem(topValue, jsonValue);
    }
    if (ArrayList(container) != none)
    {
        parser = topValue.Parse();
        if (parser.MInteger(arrayIndex, 10).Ok()) {
            ArrayList(container).SetItem(arrayIndex, jsonValue);
        }
        else if (topValue.Compare(P("-"))) {
             ArrayList(container).AddItem(jsonValue);
        }
        else {
            announcer.AnnounceFailedBadPointer(featureClass, configParameter, pathToValue);
        }
        parser.FreeSelf();
    }
    pointer.FreeSelf();
    topValue.FreeSelf();
}

/*//  TODO: autoconf, newconf, deleteconf, setconf

struct EditedConfigs
{
    var class<Feature>  featureClass;
    var HashTable       pendingSaves;
};
var private array<EditedConfigs> configEdits;*/

private function HashTable GetConfigData(
    class<Feature>  featureClass,
    BaseText        configName)
{
    local HashTable result;

    if (featureClass == none)   return none;
    if (configName == none)     return none;

    result = GetPendingConfigData(featureClass, configName);
    if (result != none) {
        return result;
    }
    return GetCurrentConfigData(featureClass, configName);
}

private function HashTable GetCurrentConfigData(
    class<Feature>  featureClass,
    BaseText        configName)
{
    local class<FeatureConfig> configClass;

    if (featureClass == none)   return none;
    if (configName == none)     return none;

    configClass = featureClass.default.configClass;
    if (configClass == none)
    {
        announcer.AnnounceFailedNoConfigClass(featureClass);
        return none;
    }
    return configClass.static.LoadData(configName);
}

private function int GetPendingConfigDataIndex(
    class<Feature> featureClass)
{
    local int i;

    for (i = 0; i < configEdits.length; i ++)
    {
        if (configEdits[i].featureClass == featureClass) {
            return i;
        }
    }
    return -1;
}

private function ChangePendingConfigData(
    class<Feature>  featureClass,
    BaseText        configName,
    HashTable       newData)
{
    local int   editsIndex;
    local Text  lowerCaseConfigName;

    if (newData == none)    return;
    if (configName == none) return;
    editsIndex = GetPendingConfigDataIndex(featureClass);
    if (editsIndex < 0)     return;

    lowerCaseConfigName = configName.LowerCopy();
    configEdits[editsIndex].pendingSaves.SetItem(configName, newData);
    lowerCaseConfigName.FreeSelf();
}

private function HashTable GetPendingConfigData(
    class<Feature>  featureClass,
    BaseText        configName,
    optional bool   createIfMissing)
{
    local int           editsIndex;
    local Text          lowerCaseConfigName;
    local HashTable     result;
    local EditedConfigs newRecord;

    if (featureClass == none)   return none;
    if (configName == none)     return none;

    lowerCaseConfigName = configName.LowerCopy();
    editsIndex = GetPendingConfigDataIndex(featureClass);
    if (editsIndex >= 0)
    {
        result = configEdits[editsIndex]
            .pendingSaves
            .GetHashTable(lowerCaseConfigName);
        if (result != none)
        {
            lowerCaseConfigName.FreeSelf();
            return result;
        }
    }
    if (createIfMissing)
    {
        if (editsIndex < 0)
        {
            editsIndex = configEdits.length;
            newRecord.featureClass = featureClass;
            newRecord.pendingSaves = _.collections.EmptyHashTable();
            configEdits[editsIndex] = newRecord;
        }
        result = GetCurrentConfigData(featureClass, configName);
        if (result != none)
        {
            configEdits[editsIndex]
                .pendingSaves
                .SetItem(lowerCaseConfigName, result);
        }
    }
    lowerCaseConfigName.FreeSelf();
    return result;
}

//  3. Add `editconf` subcommand
//  4. Add '*' for edited configs in feature display
//  5. Add `saveconf` and `--save` flag
//  6. Add `removeconf`
//  7. Add `newconf`
//  8. Add `autoconf` for setting auto config

defaultproperties
{
}
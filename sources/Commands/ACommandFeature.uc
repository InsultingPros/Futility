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
class ACommandFeature extends Command
    dependson(PendingConfigsTool);

var private class<Feature>  selectedFeatureClass;
var private Text            selectedConfigName;

var private PendingConfigsTool          pendingConfigs;
var private ACommandFeature_Announcer   announcer;

protected function Constructor()
{
    pendingConfigs =
        PendingConfigsTool(_.memory.Allocate(class'PendingConfigsTool'));
    super.Constructor();
}

protected function Finalizer()
{
    _.memory.Free(announcer);
    _.memory.Free(pendingConfigs);
    super.Finalizer();
}

protected function BuildData(CommandDataBuilder builder)
{
    builder.Name(P("feature")).Group(P("admin"))
        .Summary(P("Managing features."))
        .Describe(P("Command for managing features and their configs."));
    builder.SubCommand(P("enable"))
        .ParamText(P("feature"))
        .OptionalParams()
        .ParamText(P("config"))
        .Describe(P("Enables specified <feature>. If <config> isn't specified -"
            @ "choses the \"default\" one, making new config with default"
            @ "settings if it doesn't exist."));
    builder.SubCommand(P("disable"))
        .ParamText(P("feature"))
        .Describe(P("Disables specified <feature>."));
    builder.SubCommand(P("showconf"))
        .ParamText(P("feature"))
        .OptionalParams()
        .ParamText(P("config"))
        .Describe(P("Show given <config> for the given <feature>."));
    builder.SubCommand(P("editconf"))
        .ParamText(P("feature"))
        .ParamText(P("config"))
        .ParamText(P("variable_path"))
        .ParamRemainder(P("value"))
        .Describe(P("Changes a value inside given <config> of the given"
            @ "<feature> by setting value at JSON path <variable_path> to"
            @ "the JSON value <value>. Changes won't be immediately applied to"
            @ "the game and kept as pending."));
    builder.SubCommand(P("saveconf"))
        .ParamText(P("feature"))
        .ParamText(P("config"))
        .Describe(P("Saves pending changes for the given <config> of the given"
            @ "<feature>."));
    builder.SubCommand(P("newconf"))
        .ParamText(P("feature"))
        .ParamText(P("config"))
        .Describe(P("Creates new config for the given <feature>."));
    builder.SubCommand(P("removeconf"))
        .ParamText(P("feature"))
        .ParamText(P("config"))
        .Describe(P("Removes specified <config> of the specified <feature>."));
    builder.SubCommand(P("autoconf"))
        .ParamText(P("feature"))
        .OptionalParams()
        .ParamText(P("config"))
        .Describe(P("Changes current auto config config of the specified"
            @ "<feature>. Auto config is a config that is supposed to be"
            @ "automatically enabled at the start of the Acedia, unless"
            @ "otherwise specified for the loader."));
    builder.Option(P("all"))
        .Describe(F("Affects subcommand {$TextEmphasis showconf} by making it"
            @ "show all available configs."));
    builder.Option(P("save"))
        .Describe(F("Affects subcommand {$TextEmphasis editconf} by making it"
            @ "also save all pending changes."));
    announcer = ACommandFeature_Announcer(
        _.memory.Allocate(class'ACommandFeature_Announcer'));
}

protected function Executed(CallData arguments, EPlayer instigator)
{
    local bool saveFlag, allFlag;

    announcer.Setup(none, instigator, othersConsole);
    saveFlag    = arguments.options.HasKey(P("save"));
    allFlag     = arguments.options.HasKey(P("all"));
    SelectFeatureAndConfig(arguments);
    if (arguments.subCommandName.IsEmpty()) {
        ShowAllFeatures();
    }
    else if (arguments.subCommandName.Compare(P("enable"))) {
        EnableFeature();
    }
    else if (arguments.subCommandName.Compare(P("disable"))) {
        DisableFeature();
    }
    else if (arguments.subCommandName.Compare(P("showconf"))) {
        ShowSelectedConfigs(allFlag);
    }
    else if (arguments.subCommandName.Compare(P("editconf")))
    {
        EditFeatureConfig(
            arguments.parameters.GetText(P("variable_path")),
            arguments.parameters.GetText(P("value")),
            saveFlag);
    }
    else if (arguments.subCommandName.Compare(P("saveconf"))) {
        SaveFeatureConfig();
    }
    else if (arguments.subCommandName.Compare(P("newconf"))) {
        NewFeatureConfig();
    }
    else if (arguments.subCommandName.Compare(P("removeconf"))) {
        RemoveFeatureConfig();
    }
    else if (arguments.subCommandName.Compare(P("autoconf"))) {
        SetAutoFeatureConfig();
    }
    _.memory.Free(selectedConfigName);
    selectedConfigName = none;
}

protected function SelectFeatureAndConfig(CallData arguments)
{
    local Text userGivenFeatureName, userGivenConfigName;

    userGivenFeatureName = arguments.parameters.GetText(P("feature"));
    selectedFeatureClass = LoadFeatureClass(userGivenFeatureName);
    if (selectedFeatureClass == none && !arguments.subCommandName.IsEmpty()) {
        return;
    }
    _.memory.Free(userGivenFeatureName);
    userGivenConfigName = arguments.parameters.GetText(P("config"));
    if (userGivenConfigName != none)
    {
        selectedConfigName = userGivenConfigName.LowerCopy();
        userGivenConfigName.FreeSelf();
    }
    pendingConfigs.SelectConfig(selectedFeatureClass, selectedConfigName);
}

protected function EnableFeature()
{
    local bool      wasEnabled;
    local Text      oldConfig, newConfig;
    local Feature   instance;

    wasEnabled  = selectedFeatureClass.static.IsEnabled();
    oldConfig   = selectedFeatureClass.static.GetCurrentConfig();
    newConfig   = PickConfigBasedOnParameter();
    //  Already enabled with the same config!
    if (oldConfig != none && oldConfig.Compare(newConfig, SCASE_INSENSITIVE))
    {
        announcer.AnnounceFailedAlreadyEnabled(selectedFeatureClass, newConfig);
        _.memory.Free(newConfig);
        _.memory.Free(oldConfig);
        return;
    }
    //  Try enabling and report the result
    instance = selectedFeatureClass.static.EnableMe(newConfig);
    if (instance == none)
    {
        announcer.AnnounceFailedCannotEnableFeature(
            selectedFeatureClass,
            newConfig);
    }
    else if (wasEnabled)
    {
        announcer.AnnounceSwappedConfig(
            selectedFeatureClass,
            oldConfig,
            newConfig);
    }
    else {
        announcer.AnnounceEnabledFeature(selectedFeatureClass, newConfig);
    }
    _.memory.Free(newConfig);
    _.memory.Free(oldConfig);
}

protected function DisableFeature()
{
    if (!selectedFeatureClass.static.IsEnabled())
    {
        announcer.AnnounceFailedAlreadyDisabled(selectedFeatureClass);
        return;
    }
    selectedFeatureClass.static.DisableMe();
    //  It is possible that this command itself is destroyed after above command
    //  so do the check just in case
    if (IsAllocated()) {
        announcer.AnnounceDisabledFeature(selectedFeatureClass);
    }
}

protected function ShowSelectedConfigs(bool showAllFeatures)
{
    local int                   i;
    local array<Text>           availableConfigs;
    local MutableText           configList;
    local class<FeatureConfig>  configClass;

    if (showAllFeatures)
    {
        configClass = selectedFeatureClass.default.configClass;
        if (configClass != none) {
            availableConfigs = configClass.static.AvailableConfigs();
        }
        for (i = 0; i < availableConfigs.length; i += 1) {
            ShowFeatureConfig(availableConfigs[i]);
        }
        _.memory.FreeMany(availableConfigs);
        return;
    }
    if (selectedConfigName != none)
    {
        ShowFeatureConfig(selectedConfigName);
        return;
    }
    configList = PrintConfigList(selectedFeatureClass);
    callerConsole
        .Flush()
        .Write(P("Available configs: "))
        .WriteLine(configList);
    _.memory.Free(configList);
}

protected function ShowFeatureConfig(BaseText configName)
{
    local MutableText   dataAsJSON;
    local HashTable     currentData, pendingData;

    if (configName == none) {
        return;
    }
    currentData = GetCurrentConfigData(configName);
    if (currentData == none)
    {
        announcer.AnnounceFailedNoDataForConfig(
            selectedFeatureClass,
            configName);
        return;
    }
    //  Display current data
    dataAsJSON = _.json.PrettyPrint(currentData);
    announcer.AnnounceCurrentConfig(selectedFeatureClass, configName);
    callerConsole.Flush().WriteLine(dataAsJSON);
    _.memory.Free(dataAsJSON);
    //  Display pending data
    pendingConfigs.SelectConfig(selectedFeatureClass, configName);
    pendingData = pendingConfigs.GetPendingConfigData();
    if (pendingData != none)
    {
        dataAsJSON = _.json.PrettyPrint(pendingData);
        announcer.AnnouncePendingConfig(
            selectedFeatureClass,
            configName);
        callerConsole.Flush().WriteLine(dataAsJSON);
        _.memory.Free(dataAsJSON);
    }
    _.memory.Free(pendingData);
    _.memory.Free(currentData);
}

protected function Text PickConfigBasedOnParameter()
{
    local Text                  resolvedConfig;
    local class<FeatureConfig>  configClass;

    configClass = selectedFeatureClass.default.configClass;
    if (configClass == none)
    {
        announcer.AnnounceFailedNoConfigClass(selectedFeatureClass);
        return none;
    }
    //  If config was specified - simply check that it exists
    if (selectedConfigName != none)
    {
        if (configClass.static.Exists(selectedConfigName)) {
            return selectedConfigName.Copy();
        }
        announcer.AnnounceFailedConfigMissing(selectedConfigName);
        return none;
    }
    //  If it wasn't specified - try auto config instead
    resolvedConfig = configClass.static.GetAutoEnabledConfig();
    if (resolvedConfig == none) {
        announcer.AnnounceFailedNoConfigProvided(selectedFeatureClass);
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

protected function ShowFeature(class<Feature> featureClass)
{
    local MutableText featureName;
    local MutableText configList;

    if (featureClass == none) {
        return;
    }
    featureName = _.text
        .FromClassM(featureClass)
        .ChangeDefaultColor(_.color.TextEmphasis);
    configList = PrintConfigList(featureClass);
    callerConsole.Flush();
    if (featureClass.static.IsEnabled()) {
        callerConsole.Write(F("[  {$TextPositive enabled} ] "));
    }
    else {
        callerConsole.Write(F("[ {$TextNegative disabled} ] "));
    }
    callerConsole.Write(featureName)
        .Write(P(" with configs: "))
        .WriteLine(configList);
    _.memory.Free(featureName);
    _.memory.Free(configList);
}

protected function MutableText PrintConfigList(class<Feature> featureClass)
{
    local int                   i;
    local Text                  autoConfig;
    local ListBuilder           configList;
    local MutableText           result, nextConfig;
    local array<Text>           availableConfigs;
    local class<FeatureConfig>  configClass;

    if (featureClass == none)   return none;
    configClass = featureClass.default.configClass;
    if (configClass == none)    return none;

    availableConfigs    = configClass.static.AvailableConfigs();
    autoConfig          = configClass.static.GetAutoEnabledConfig();
    configList          = ListBuilder(_.memory.Allocate(class'ListBuilder'));
    for (i = 0; i < availableConfigs.length; i += 1)
    {
        nextConfig = availableConfigs[i].MutableCopy();
        if (pendingConfigs.HasPendingConfigFor(featureClass, nextConfig)) {
            nextConfig.Append(F("{$TextEmphasis *}"));
        }
        configList.Item(nextConfig);
        _.memory.Free(nextConfig);
        if (    autoConfig != none
            &&  autoConfig.Compare(availableConfigs[i], SCASE_INSENSITIVE))
        {
            configList.Comment(F("{$TextPositive auto enabled}"));
        }
    }
    result = configList.GetMutable();
    _.memory.Free(configList);
    _.memory.Free(autoConfig);
    _.memory.FreeMany(availableConfigs);
    return result;
}

protected function MutableText PrettyPrintValueAt(BaseText pathToValue)
{
    local MutableText   printedValue;
    local AcediaObject  value;
    local HashTable     relevantData;

    relevantData = pendingConfigs.GetPendingConfigData();
    if (relevantData == none) {
        relevantData = GetCurrentSelectedConfigData();
    }
    if (relevantData != none) {
        value = relevantData.GetItemBy(pathToValue);
    }
    if (value != none)
    {
        printedValue = _.json.PrettyPrint(value);
        _.memory.Free(value);
    }
    _.memory.Free(relevantData);
    return printedValue;
}

protected function EditFeatureConfig(
    BaseText    pathToValue,
    BaseText    newValue,
    bool        saveConfig)
{
    local MutableText printedOldValue;
    local MutableText printedNewValue;
    local PendingConfigsTool.PendingConfigToolResult error;

    printedOldValue = PrettyPrintValueAt(pathToValue);
    error = pendingConfigs.EditConfig(pathToValue, newValue);
    if (error == PCTE_None) {
        printedNewValue = PrettyPrintValueAt(pathToValue);
    }
    if (error == PCTE_ConfigMissing) {
        announcer.AnnounceFailedConfigMissing(selectedConfigName);
    }
    else if (error == PCTE_ExpectedObject) {
        announcer.AnnounceFailedExpectedObject();
    }
    else if (error == PCTE_BadPointer)
    {
        announcer.AnnounceFailedBadPointer(
            selectedFeatureClass,
            selectedConfigName,
            pathToValue);
    }
    else if (printedOldValue == none)
    {
        announcer.AnnounceConfigNewValue(
            selectedFeatureClass,
            selectedConfigName,
            pathToValue,
            printedNewValue);
    }
    else
    {
        announcer.AnnounceConfigEdited(
            selectedFeatureClass,
            selectedConfigName,
            pathToValue,
            printedOldValue,
            printedNewValue);
    }
    if (saveConfig && error == PCTE_None) {
        SaveFeatureConfig();
    }
    _.memory.Free(printedOldValue);
    _.memory.Free(printedNewValue);
}

protected function SaveFeatureConfig()
{
    local BaseText              enabledConfigName;
    local HashTable             pendingData;
    local class<FeatureConfig>  configClass;

    configClass = selectedFeatureClass.default.configClass;
    if (configClass == none)
    {
        announcer.AnnounceFailedNoConfigClass(selectedFeatureClass);
        return;
    }
    pendingData = pendingConfigs.GetPendingConfigData();
    if (pendingData == none)
    {
        announcer.AnnounceFailedPendingConfigMissing(selectedConfigName);
        return;
    }
    //  Make sure config exists
    configClass.static.NewConfig(selectedConfigName);
    configClass.static.SaveData(selectedConfigName, pendingData);
    //  Re-apply config if it is active?
    enabledConfigName = selectedFeatureClass.static.GetCurrentConfig();
    if (selectedConfigName.Compare(enabledConfigName, SCASE_INSENSITIVE))
    {
        selectedFeatureClass.static.EnableMe(selectedConfigName);
        announcer.AnnouncePublicPendingConfigSaved(selectedFeatureClass);
    }
    else {
        announcer.AnnouncePrivatePendingConfigSaved(selectedFeatureClass);
    }
    _.memory.Free(enabledConfigName);
    pendingData.FreeSelf();
    pendingConfigs.RemoveConfig();
    return;
}

protected function NewFeatureConfig()
{
    local BaseText              enabledConfigName;
    local class<FeatureConfig>  configClass;

    configClass = selectedFeatureClass.default.configClass;
    if (configClass == none)
    {
        announcer.AnnounceFailedNoConfigClass(selectedFeatureClass);
        return;
    }
    if (configClass.static.Exists(selectedConfigName))
    {
        announcer.AnnounceFailedConfigAlreadyExists(
            selectedFeatureClass,
            selectedConfigName);
        return;
    }
    if (!configClass.static.NewConfig(selectedConfigName))
    {
        announcer.AnnounceFailedBadConfigName(selectedConfigName);
        return;
    }
    enabledConfigName = selectedFeatureClass.static.GetCurrentConfig();
    if (selectedConfigName.Compare(enabledConfigName, SCASE_INSENSITIVE))
    {
        selectedFeatureClass.static.EnableMe(selectedConfigName);
        announcer.AnnouncePublicPendingConfigSaved(selectedFeatureClass);
    }
    _.memory.Free(enabledConfigName);
    announcer.AnnounceConfigCreated(selectedFeatureClass, selectedConfigName);
}

protected function RemoveFeatureConfig()
{
    local class<FeatureConfig> configClass;

    configClass = selectedFeatureClass.default.configClass;
    if (configClass == none)
    {
        announcer.AnnounceFailedNoConfigClass(selectedFeatureClass);
        return;
    }
    if (!configClass.static.Exists(selectedConfigName))
    {
        announcer.AnnounceFailedConfigDoesNotExist(
            selectedFeatureClass,
            selectedConfigName);
        return;
    }
    pendingConfigs.RemoveConfig();
    configClass.static.DeleteConfig(selectedConfigName);
    announcer.AnnounceConfigRemoved(selectedFeatureClass, selectedConfigName);
}

protected function SetAutoFeatureConfig()
{
    local Text                  currentAutoEnabledConfig;
    local class<FeatureConfig>  configClass;

    configClass = selectedFeatureClass.default.configClass;
    if (configClass == none)
    {
        announcer.AnnounceFailedNoConfigClass(selectedFeatureClass);
        return;
    }
    if (    selectedConfigName != none
        &&  !configClass.static.Exists(selectedConfigName))
    {
        announcer.AnnounceFailedConfigDoesNotExist(
            selectedFeatureClass,
            selectedConfigName);
        return;
    }
    currentAutoEnabledConfig = configClass.static.GetAutoEnabledConfig();
    if (selectedConfigName == none && currentAutoEnabledConfig == none) {
        announcer.AnnounceFailedAlreadyNoAutoEnabled(selectedFeatureClass);
    }
    else if (selectedConfigName != none &&
        selectedConfigName.Compare(currentAutoEnabledConfig, SCASE_INSENSITIVE))
    {
        announcer.AnnounceFailedAlreadySameAutoEnabled(
            selectedFeatureClass,
            selectedConfigName);
    }
    else
    {
        configClass.static.SetAutoEnabledConfig(selectedConfigName);
        if (selectedConfigName != none)
        {
            announcer.AnnounceAutoEnabledConfig(
                selectedFeatureClass,
                selectedConfigName);
        }
        else {
            announcer.AnnounceRemovedAutoEnabledConfig(selectedFeatureClass);
        }
    }
    _.memory.Free(currentAutoEnabledConfig);
}

private function HashTable GetCurrentConfigData(BaseText configName)
{
    local class<FeatureConfig> configClass;

    if (configName == none) {
        return none;
    }
    configClass = selectedFeatureClass.default.configClass;
    if (configClass == none)
    {
        announcer.AnnounceFailedNoConfigClass(selectedFeatureClass);
        return none;
    }
    return configClass.static.LoadData(configName);
}

private function HashTable GetCurrentSelectedConfigData()
{
    return GetCurrentConfigData(selectedConfigName);
}

defaultproperties
{
}
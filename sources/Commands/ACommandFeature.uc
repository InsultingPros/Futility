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
    local Text userGivenFeatureName, userGivenConfigName;

    announcer.Setup(none, instigator, othersConsole);
    userGivenFeatureName = arguments.parameters.GetText(P("feature"));
    selectedFeatureClass = LoadFeatureClass(userGivenFeatureName);
    _.memory.Free(userGivenFeatureName);
    userGivenConfigName = arguments.parameters.GetText(P("config"));
    if (userGivenConfigName != none)
    {
        selectedConfigName = userGivenConfigName.LowerCopy();
        userGivenConfigName.FreeSelf();
    }
    pendingConfigs.SelectConfig(selectedFeatureClass, selectedConfigName);
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
        ShowFeatureConfig();
    }
    else if (arguments.subCommandName.Compare(P("editconf")))
    {
        EditFeatureConfig(
            arguments.parameters.GetText(P("variable path")),
            arguments.parameters.GetText(P("value")));
    }
    _.memory.Free(selectedConfigName);
    selectedConfigName = none;
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

protected function ShowFeatureConfig()
{
    local MutableText   dataAsJSON;
    local HashTable     currentData, pendingData;

    if (selectedConfigName == none) {
        return;
    }
    currentData = GetCurrentConfigData();
    if (currentData == none)
    {
        announcer.AnnounceFailedNoDataForConfig(
            selectedFeatureClass,
            selectedConfigName);
        return;
    }
    //  Display current data
    dataAsJSON = _.json.PrettyPrint(currentData);
    announcer.AnnounceCurrentConfig(selectedFeatureClass, selectedConfigName);
    callerConsole.Flush().WriteLine(dataAsJSON);
    _.memory.Free(dataAsJSON);
    //  Display pending data
    pendingData = pendingConfigs.GetPendingConfigData();
    if (pendingData != none)
    {
        dataAsJSON = _.json.PrettyPrint(pendingData);
        announcer.AnnouncePendingConfig(
            selectedFeatureClass,
            selectedConfigName);
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

protected function ShowFeature(class<Feature> feature)
{
    local int                   i;
    local Text                  autoConfig;
    local MutableText           featureName, builder, nextConfig;
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
        builder.Append(P(" with config: "));
    }
    else if (availableConfigs.length > 1) {
        builder.Append(P(" with configs: "));
    }
    callerConsole.Write(builder);
    _.memory.Free(builder);
    configList = ListBuilder(_.memory.Allocate(class'ListBuilder'));
    autoConfig = configClass.static.GetAutoEnabledConfig();
    for (i = 0; i < availableConfigs.length; i += 1)
    {
        nextConfig = availableConfigs[i].MutableCopy();
        if (pendingConfigs.HasPendingConfigFor(feature, nextConfig)) {
            nextConfig.Append(P("*"));
        }
        configList.Item(nextConfig);
        _.memory.Free(nextConfig);
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

protected function EditFeatureConfig(BaseText pathToValue, BaseText newValue)
{
    local PendingConfigsTool.PendingConfigToolError error;

    error = pendingConfigs.ChangeConfig(pathToValue, newValue);
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
}

private function HashTable GetCurrentConfigData()
{
    local class<FeatureConfig> configClass;

    if (selectedConfigName == none) {
        return none;
    }
    configClass = selectedFeatureClass.default.configClass;
    if (configClass == none)
    {
        announcer.AnnounceFailedNoConfigClass(selectedFeatureClass);
        return none;
    }
    return configClass.static.LoadData(selectedConfigName);
}

//  5. Add `saveconf` and `--save` flag
//  6. Add `removeconf`
//  7. Add `newconf`
//  8. Add `autoconf` for setting auto config

defaultproperties
{
}
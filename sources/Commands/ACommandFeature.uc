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
//  TODO: when displaying features - display which one is enabled

var private ACommandFeature_Announcer announcer;

protected function Finalizer()
{
    _.memory.Free(announcer);
    super.Finalizer();
}

protected function BuildData(CommandDataBuilder builder)
{
    builder.Name(P("feature")).Summary(P("Managing features."))
        .Describe(P("Command for displaying and enabling/disabling features."));
    builder.SubCommand(P("enable"))
        .ParamText(P("feature"))
        .OptionalParams()
        .ParamText(P("config"))
        .Describe(P("Enables specified <feature>."));
    builder.SubCommand(P("disable"))
        .ParamText(P("feature"))
        .Describe(P("Disables specified <feature>."));
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
    wasEnabled = featureClass.static.IsEnabled();
    oldConfig = featureClass.static.GetCurrentConfig();
    newConfig = GetConfigFromParameter(configParameter, featureClass);
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

protected function Text GetConfigFromParameter(
    BaseText        configParameter,
    class<Feature>  featureClass)
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
    local ReportTool            reportTool;
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
        .ChangeDefaultFormatting(
            _.text.FormattingFromColor(_.color.TextEmphasis));
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
    reportTool = ReportTool(_.memory.Allocate(class'ReportTool'));
    reportTool.Initialize(builder);
    _.memory.Free(builder);
    autoConfig = configClass.static.GetAutoEnabledConfig();
    for (i = 0; i < availableConfigs.length; i += 1)
    {
        builder = _.text.Empty().Append(availableConfigs[i]);
        reportTool.Item(builder);
        if (    autoConfig != none
            &&  autoConfig.Compare(availableConfigs[i], SCASE_INSENSITIVE))
        {
            reportTool.Detail(F("{$TextPositive auto enabled}"));
        }
        _.memory.Free(builder);
        builder = none;
    }
    reportTool.Report(callerConsole);
    _.memory.FreeMany(availableConfigs);
    _.memory.Free(reportTool);
    _.memory.Free(autoConfig);
}

defaultproperties
{
}
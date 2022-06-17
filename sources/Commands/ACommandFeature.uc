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
}

protected function Executed(CallData result, EPlayer callerPlayer)
{
    if (result.subCommandName.IsEmpty()) {
        ShowAllFeatures();
    }
    else if (result.subCommandName.Compare(P("enable")))
    {
        TryEnableFeature(
            callerPlayer,
            result.parameters.GetText(P("feature")),
            result.parameters.GetText(P("config")));
    }
    else if (result.subCommandName.Compare(P("disable"))) {
        DisableFeature(callerPlayer, result.parameters.GetText(P("feature")));
    }
}

protected function TryEnableFeature(
    EPlayer callerPlayer,
    Text    featureName,
    Text    chosenConfig)
{
    local Text                  oldConfig, newConfig;
    local class<Feature>        featureClass;
    local class<FeatureConfig>  configClass;
    featureClass = LoadFeatureClass(featureName);
    if (featureClass == none)   return;
    configClass = featureClass.default.configClass;
    if (configClass == none)    return;

    if (chosenConfig == none) {
        newConfig = configClass.static.GetAutoEnabledConfig();
    }
    else if (!configClass.static.Exists(chosenConfig))
    {
        callerConsole
            .Write(P("Specified config \""))
            .Write(chosenConfig)
            .WriteLine(F("\" {$TextFailure doesn't exist}"));
        return;
    }
    else {
        newConfig = chosenConfig.Copy();
    }
    if (newConfig == none)
    {
        callerConsole
            .Write(F("{$TextFailue No config specified} and"
                @ "{$TextFailure no auto-enabled config} exists for feature "))
            .UseColorOnce(_.color.TextEmphasis)
            .WriteLine(newConfig);
         _.memory.Free(newConfig);
        return;
    }
    oldConfig = featureClass.static.GetCurrentConfig();
    if (oldConfig != none && oldConfig.Compare(chosenConfig, SCASE_INSENSITIVE))
    {
        callerConsole
            .Write(P("Config "))
            .Write(chosenConfig)
            .WriteLine(P(" is already enabled"));
        _.memory.Free(oldConfig);
        _.memory.Free(newConfig);
        return;
    }
    EnableFeature(
        callerPlayer,
        featureClass,
        configClass,
        newConfig,
        chosenConfig == none);
    _.memory.Free(newConfig);
    _.memory.Free(oldConfig);
}

protected function EnableFeature(
    EPlayer                 callerPlayer,
    class<Feature>          featureClass,
    class<FeatureConfig>    configClass,
    Text                    chosenConfig,
    bool                    autoConfig)
{
    local bool      wasEnabled;
    local Feature   instance;
    local Text      featureName, callerName;
    if (callerPlayer == none)   return;
    if (featureClass == none)   return;
    if (configClass == none)    return;

    callerName = callerPlayer.GetName();
    featureName = _.text.FromClass(featureClass);
    wasEnabled = featureClass.static.IsEnabled();
    instance = featureClass.static.EnableMe(chosenConfig);
    if (instance == none)
    {
        callerConsole.Write(F("Something went {$TextFailure wrong},"
            @ "{$TextFailure failed} to enabled feature"))
            .UseColorOnce(_.color.TextEmphasis).WriteLine(featureName);
    }
    else if (wasEnabled)
    {
        callerConsole
            .Write(P("Swapping config for the feature "))
            .UseColorOnce(_.color.TextEmphasis).Write(featureName)
            .Write(P(" to \"")).Write(chosenConfig).WriteLine(P("\""));
        othersConsole
            .Write(callerName)
            .Write(P(" swapped config for the feature "))
            .UseColorOnce(_.color.TextEmphasis).Write(featureName)
            .Write(P(" to \"")).Write(chosenConfig).WriteLine(P("\""));
    }
    else
    {
        callerConsole
            .Write(P("Enabling feature "))
            .UseColorOnce(_.color.TextEmphasis).Write(featureName)
            .Write(P(" with config \"")).Write(chosenConfig).WriteLine(P("\""));
        othersConsole
            .Write(callerName)
            .Write(P(" enabled feature "))
            .UseColorOnce(_.color.TextEmphasis).Write(featureName)
            .Write(P(" with config \"")).Write(chosenConfig).WriteLine(P("\""));
    }
    _.memory.Free(callerName);
    _.memory.Free(featureName);
}

protected function DisableFeature(EPlayer callerPlayer, Text featureName)
{
    local Text              playerName;
    local Text              featureRealName;
    local class<Feature>    featureClass;
    featureClass = LoadFeatureClass(featureName);
    if (featureClass == none)   return;
    if (callerPlayer == none)   return;

    featureRealName = _.text.FromClass(featureClass);
    playerName      = callerPlayer.GetName();
    if (!featureClass.static.IsEnabled())
    {
        callerConsole
            .Write(P("Feature "))
            .UseColorOnce(_.color.TextEmphasis).Write(featureRealName)
            .WriteLine(F(" is already {$TextNegative disabled}"));
        _.memory.Free(featureRealName);
        _.memory.Free(playerName);
        return;
    }
    featureClass.static.DisableMe();
    callerConsole
            .Write(P("Feature "))
            .UseColorOnce(_.color.TextEmphasis).Write(featureRealName)
            .WriteLine(F(" is {$TextNegative disabled}"));
    othersConsole
            .Write(playerName).Write(F(" {$TextNegative disabled} feature "))
            .UseColorOnce(_.color.TextEmphasis).WriteLine(featureRealName);
    _.memory.Free(featureRealName);
    _.memory.Free(playerName);
}

protected function class<Feature> LoadFeatureClass(Text featureName)
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
    if (featureClass == none)
    {
        callerConsole
            .Write(F("{$TextFailure Failed} to load feature `"))
            .Write(featureName)
            .WriteLine(P("`"));
    }
    _.memory.Free(featureClassName);
    return featureClass;
}

protected function ShowAllFeatures()
{
    local int                       i;
    local CoreService               service;
    local array< class<Feature> >   availableFeatures;
    service = CoreService(class'CoreService'.static.Require());
    availableFeatures = service.GetAvailableFeatures();
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
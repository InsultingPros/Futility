/**
 *      Announcer for `ACommandFeature`.
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
class ACommandFeature_Announcer extends CommandAnnouncer;

var private AnnouncementVariations enabledFeature, disabledFeature;
var private AnnouncementVariations swappedConfig;
var private AnnouncementVariations showCurrentConfig, showPendingConfig;
var private AnnouncementVariations failedToLoadFeatureClass;
var private AnnouncementVariations failedNoConfigProvided, failedConfigMissing;
var private AnnouncementVariations failedCannotEnableFeature;
var private AnnouncementVariations failedNoConfigClass;
var private AnnouncementVariations failedAlreadyEnabled, failedAlreadyDisabled;
var private AnnouncementVariations failedNoDataForConfig, failedExpectedObject;
var private AnnouncementVariations failedBadPointer;

protected function Finalizer()
{
    FreeVariations(enabledFeature);
    FreeVariations(disabledFeature);
    FreeVariations(swappedConfig);
    FreeVariations(showCurrentConfig);
    FreeVariations(showPendingConfig);
    FreeVariations(failedToLoadFeatureClass);
    FreeVariations(failedNoConfigProvided);
    FreeVariations(failedConfigMissing);
    FreeVariations(failedCannotEnableFeature);
    FreeVariations(failedNoConfigClass);
    FreeVariations(failedAlreadyEnabled);
    FreeVariations(failedAlreadyDisabled);
    FreeVariations(failedNoDataForConfig);
    FreeVariations(failedExpectedObject);
    FreeVariations(failedBadPointer);
    super.Finalizer();
}

public final function AnnounceEnabledFeature(
    class<Feature>  featureClass,
    BaseText        configName)
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!enabledFeature.initialized)
    {
        enabledFeature.initialized = true;
        enabledFeature.toSelfReport = _.text.MakeTemplate_S(
            "Feature {$TextEmphasis `%1`} {$TextPositive enabled} with config"
            @ "\"%2\"");
        enabledFeature.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextPositive enabled} feature"
            @ "{$TextEmphasis `%1`} with config \"%2\"");
    }
    templates = MakeArray(enabledFeature);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().ArgClass(featureClass).Arg(configName);
    }
    MakeAnnouncement(enabledFeature);
}

public final function AnnounceDisabledFeature(class<Feature> featureClass)
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!disabledFeature.initialized)
    {
        disabledFeature.initialized = true;
        disabledFeature.toSelfReport = _.text.MakeTemplate_S(
            "Feature {$TextEmphasis `%1`} {$TextNegative disabled}");
        disabledFeature.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextNegative disabled} feature"
            @ "{$TextEmphasis `%1`}");
    }
    templates = MakeArray(disabledFeature);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().ArgClass(featureClass);
    }
    MakeAnnouncement(disabledFeature);
}

public final function AnnounceSwappedConfig(
    class<Feature>  featureClass,
    BaseText        oldConfig,
    BaseText        newConfig)
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!swappedConfig.initialized)
    {
        swappedConfig.initialized = true;
        swappedConfig.toSelfReport = _.text.MakeTemplate_S(
            "Config for feature {$TextEmphasis `%1`} {$TextNeutral swapped}"
            @ "from \"%2\" to \"%3\"");
        swappedConfig.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextNeutral swapped} config for feature"
            @ "{$TextEmphasis `%1`} from \"%2\" to \"%3\"");
    }
    templates = MakeArray(swappedConfig);
    for (i = 0; i < templates.length; i += 1)
    {
        templates[i]
            .Reset()
            .ArgClass(featureClass)
            .Arg(oldConfig)
            .Arg(newConfig);
    }
    MakeAnnouncement(swappedConfig);
}

public final function AnnounceCurrentConfig(
    class<Feature>  featureClass,
    BaseText        config)
{
    if (!showCurrentConfig.initialized)
    {
        showCurrentConfig.initialized = true;
        showCurrentConfig.toSelfReport = _.text.MakeTemplate_S(
            "Current config \"%2\" for feature {$TextEmphasis `%1`}:");
    }
    showCurrentConfig.toSelfReport
        .Reset()
        .ArgClass(featureClass)
        .Arg(config);
    MakeAnnouncement(showCurrentConfig);
}

public final function AnnouncePendingConfig(
    class<Feature>  featureClass,
    BaseText        config)
{
    if (!showPendingConfig.initialized)
    {
        showPendingConfig.initialized = true;
        showPendingConfig.toSelfReport = _.text.MakeTemplate_S(
            "Pending config \"%2\" for feature {$TextEmphasis `%1`}:");
    }
    showPendingConfig.toSelfReport
        .Reset()
        .ArgClass(featureClass)
        .Arg(config);
    MakeAnnouncement(showPendingConfig);
}

public final function AnnounceFailedToLoadFeatureClass(BaseText failedClassName)
{
    if (!failedToLoadFeatureClass.initialized)
    {
        failedToLoadFeatureClass.initialized = true;
        failedToLoadFeatureClass.toSelfReport = _.text.MakeTemplate_S(
            "{$TextFailure Failed} to load feature class {$TextEmphasis `%1`}");
    }
    failedToLoadFeatureClass.toSelfReport.Reset().Arg(failedClassName);
    MakeAnnouncement(failedToLoadFeatureClass);
}

public final function AnnounceFailedNoConfigProvided(
    class<Feature> featureClass)
{
    if (!failedNoConfigProvided.initialized)
    {
        failedNoConfigProvided.initialized = true;
        failedNoConfigProvided.toSelfReport = _.text.MakeTemplate_S(
            "{$TextFailue No config specified} and {$TextFailure no"
            @ "auto-enabled config} exists for feature {$TextEmphasis `%1`}");
    }
    failedNoConfigProvided.toSelfReport.Reset().ArgClass(featureClass);
    MakeAnnouncement(failedNoConfigProvided);
}

public final function AnnounceFailedConfigMissing(BaseText config)
{
    if (!failedConfigMissing.initialized)
    {
        failedConfigMissing.initialized = true;
        failedConfigMissing.toSelfReport = _.text.MakeTemplate_S(
            "Specified config \"%1\" {$TextFailue doesn't exist}");
    }
    failedConfigMissing.toSelfReport.Reset().Arg(config);
    MakeAnnouncement(failedConfigMissing);
}

public final function AnnounceFailedCannotEnableFeature(
    class<Feature>  featureClass,
    BaseText        config)
{
    if (!failedCannotEnableFeature.initialized)
    {
        failedCannotEnableFeature.initialized = true;
        failedCannotEnableFeature.toSelfReport = _.text.MakeTemplate_S(
            "Something went {$TextFailure wrong}, {$TextFailure failed} to"
            @ "enable feature {$TextEmphasis `%1`} with config \"%2\"");
    }
    failedCannotEnableFeature.toSelfReport
        .Reset()
        .ArgClass(featureClass)
        .Arg(config);
    MakeAnnouncement(failedCannotEnableFeature);
}

public final function AnnounceFailedNoConfigClass(
    class<Feature> featureClass)
{
    if (!failedNoConfigClass.initialized)
    {
        failedNoConfigClass.initialized = true;
        failedNoConfigClass.toSelfReport = _.text.MakeTemplate_S(
            "Feature {$TextEmphasis `%1`} {$TextFailure does not have config"
            @ "class}! This is most likely caused by its faulty"
            @ "implementation");
    }
    failedNoConfigClass.toSelfReport.Reset().ArgClass(featureClass);
    MakeAnnouncement(failedNoConfigClass);
}

public final function AnnounceFailedAlreadyDisabled(
    class<Feature> featureClass)
{
    if (!failedAlreadyDisabled.initialized)
    {
        failedAlreadyDisabled.initialized = true;
        failedAlreadyDisabled.toSelfReport = _.text.MakeTemplate_S(
            "Feature {$TextEmphasis `%1`} is already {$TextNegative disabled}");
    }
    failedAlreadyDisabled.toSelfReport.Reset().ArgClass(featureClass);
    MakeAnnouncement(failedAlreadyDisabled);
}

public final function AnnounceFailedAlreadyEnabled(
    class<Feature>  featureClass,
    BaseText        config)
{
    if (!failedAlreadyEnabled.initialized)
    {
        failedAlreadyEnabled.initialized = true;
        failedAlreadyEnabled.toSelfReport = _.text.MakeTemplate_S(
            "Feature {$TextEmphasis `%1`} is already {$TextNegative enabled}"
            @ "with specified config \"%2\"");
    }
    failedAlreadyEnabled.toSelfReport
        .Reset()
        .ArgClass(featureClass)
        .Arg(config);
    MakeAnnouncement(failedAlreadyEnabled);
}

public final function AnnounceFailedNoDataForConfig(
    class<Feature>  featureClass,
    BaseText        config)
{
    if (!failedNoDataForConfig.initialized)
    {
        failedNoDataForConfig.initialized = true;
        failedNoDataForConfig.toSelfReport = _.text.MakeTemplate_S(
            "Feature {$TextEmphasis `%1`} is missing data for config \"%2\"");
    }
    failedNoDataForConfig.toSelfReport
        .Reset()
        .ArgClass(featureClass)
        .Arg(config);
    MakeAnnouncement(failedNoDataForConfig);
}

public final function AnnounceFailedExpectedObject()
{
    if (!failedExpectedObject.initialized)
    {
        failedExpectedObject.initialized = true;
        failedExpectedObject.toSelfReport = _.text.MakeTemplate_S(
            "When changing the value of the whole config, a JSON object must be"
            @ "provided");
    }
    MakeAnnouncement(failedExpectedObject);
}

public final function AnnounceFailedBadPointer(
    class<Feature>  featureClass,
    BaseText        config,
    BaseText        pointer)
{
    if (!failedBadPointer.initialized)
    {
        failedBadPointer.initialized = true;
        failedBadPointer.toSelfReport = _.text.MakeTemplate_S(
            "Provided JSON pointer \"%3\" is invalid for config \"%2\" of"
            @ "feature {$TextEmphasis `%1`}");
    }
    failedBadPointer.toSelfReport
        .Reset()
        .ArgClass(featureClass)
        .Arg(config)
        .Arg(pointer);
    MakeAnnouncement(failedBadPointer);
}

defaultproperties
{
}
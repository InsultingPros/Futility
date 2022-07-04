/**
 *      Config object for `Futility_Feature`.
 *      Copyright 2021-2022 Anton Tarasenko
 *------------------------------------------------------------------------------
 * This file is part of Futility.
 *
 * Futility is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License, or
 * (at your option) any later version.
 *
 * Futility is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Futility.  If not, see <https://www.gnu.org/licenses/>.
 */
class Futility extends FeatureConfig
    perobjectconfig
    config(Futility);

protected function HashTable ToData()
{
    return _.collections.EmptyHashTable();
}

protected function FromData(HashTable source)
{
}

protected function DefaultIt()
{
}

defaultproperties
{
    configName = "Futility"
}
assert  = require 'assert'
ld      = require 'lodash'
async   = require 'async'
{optCb} = require '../utils'
matchApi = require './match'

api = exports.api = {
    fullname: "game-v1.3",
    name: "game",
    version: "v1.3"
}

exports.methods = {
    # Gets recent games for this given summoner.
    #
    # Parameters:
    # * `summonerId` - ID of the summoner for which to retrieve recent games.
    # * `options.region` - Region where to retrieve the data.
    # * `options.asMatches` - if specified, this will use the `match` api to fetch match objects for
    #   each game.  These objects will automatically  be populated with summoner identities, even
    #   if they are not ranked games.  `asMatches` can either be `true`, or can be a hash of
    #   options which will be passed to `getMatch()` (e.g. `{includeTimeline: true}`)
    #
    # Returns a `{games, summonerId}` object.  If `options.asMatches` is specified, returns a
    # `{games, matches, summonerId}` object.
    #
    getRecentGamesForSummoner: optCb (summonerId, options, _) ->
        # Since we're relying on other APIs, we assert here so that if those APIs change, we'll get
        # unit test failures if we don't update this method.
        assert.equal(matchApi.api.version, "v2.2", "match API version has changed.")

        region = options.region ? @defaultRegion

        requestParams = {
            caller: "getRecentGamesForSummoner",
            region: region,
            url: "#{@_makeUrl region, api}/by-summoner/#{summonerId}/recent"
        }
        cacheParams = {
            key: "#{api.fullname}-games-#{region}-#{summonerId}"
            region, api,
            objectType: 'games'
            params: {summonerId}
        }

        games = @_riotRequestWithCache requestParams, cacheParams, {}, _

        if options.asMatches
            # Fetch matches in parallel
            games.matches = async.map games.games,
                ((game, _) =>
                    matchOptions = if options.asMatches is true
                        {region}
                    else
                        ld.extend {}, options.asMatches, {region}
                    matchOptions.players = ld.clone game.fellowPlayers
                    matchOptions.players.push {
                        championId: game.championId,
                        teamId: game.teamId,
                        summonerId
                    }
                    return @getMatch game.gameId, matchOptions, _
                ), _

        return games

}
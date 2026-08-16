package anilist

// mediaFields is the shared GraphQL selection fragment for media entries.
const mediaFields = `
id
title { romaji english native }
coverImage { extraLarge large medium }
bannerImage
description
averageScore
genres
episodes
season
seasonYear
format
status
isAdult
source
countryOfOrigin
hashtag
siteUrl
updatedAt
startDate { year month day }
endDate { year month day }
studios(isMain: true) { nodes { name } }
externalLinks { id url site type notes }
`

// searchQuery searches media by title with optional filtering.
const searchQuery = `query ($search: String, $page: Int, $perPage: Int, $type: MediaType, $genre: String, $tag: String, $status: MediaStatus, $season: MediaSeason, $seasonYear: Int, $sort: [MediaSort]) {
  Page(page: $page, perPage: $perPage) {
    pageInfo { total currentPage lastPage hasNextPage perPage }
    media(search: $search, type: $type, genre: $genre, tag: $tag, status: $status, season: $season, seasonYear: $seasonYear, sort: $sort) {
      ` + mediaFields + `
    }
  }
}`

// genresQuery fetches the global list of media genres.
const genresQuery = `query {
  GenreCollection
}`

// byIDQuery fetches a single media entry by id.
const byIDQuery = `query ($id: Int) {
  Media(id: $id, type: ANIME) {
    ` + mediaFields + `
  }
}`

// airingQuery fetches media by status with optional genre/tag filters.
const airingQuery = `query ($status: MediaStatus, $genre: String, $tag: String, $page: Int, $perPage: Int, $sort: [MediaSort]) {
  Page(page: $page, perPage: $perPage) {
    pageInfo { total currentPage lastPage hasNextPage perPage }
    media(status: $status, genre: $genre, tag: $tag, type: ANIME, sort: $sort) {
      ` + mediaFields + `
    }
  }
}`

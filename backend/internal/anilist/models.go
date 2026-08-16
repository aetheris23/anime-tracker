package anilist

// Title holds the localized titles of a media entry.
type Title struct {
	Romaji  string `json:"romaji"`
	English string `json:"english"`
	Native  string `json:"native"`
}

// FuzzyDate is a possibly incomplete date.
type FuzzyDate struct {
	Year  int `json:"year"`
	Month int `json:"month"`
	Day   int `json:"day"`
}

// CoverImage holds artwork URLs.
type CoverImage struct {
	ExtraLarge string `json:"extraLarge"`
	Large      string `json:"large"`
	Medium     string `json:"medium"`
}

// StudioNode is a single studio entry.
type StudioNode struct {
	Name string `json:"name"`
}

// Studios wraps the main studios of a media.
type Studios struct {
	Nodes []StudioNode `json:"nodes"`
}

// Anime is the core data model exposed by the API.
type Anime struct {
	ID              int            `json:"id"`
	Title           Title          `json:"title"`
	CoverImage      CoverImage     `json:"coverImage"`
	BannerImage     string         `json:"bannerImage"`
	Description     string         `json:"description"`
	AverageScore    *int           `json:"averageScore"`
	Genres          []string       `json:"genres"`
	Episodes        *int           `json:"episodes"`
	Season          *string        `json:"season"`
	SeasonYear      *int           `json:"seasonYear"`
	Format          string         `json:"format"`
	Status          string         `json:"status"`
	StartDate       FuzzyDate      `json:"startDate"`
	EndDate         FuzzyDate      `json:"endDate"`
	UpdatedAt       int64          `json:"updatedAt"`
	Studios         Studios        `json:"studios"`
	IsAdult         bool           `json:"isAdult"`
	Hashtag         string         `json:"hashtag"`
	SiteUrl         string         `json:"siteUrl"`
	ExternalLinks   []ExternalLink `json:"externalLinks"`
	Source          string         `json:"source"`
	CountryOfOrigin string         `json:"countryOfOrigin"`
}

// ExternalLink is a link to an external site (e.g. official stream).
type ExternalLink struct {
	ID    int    `json:"id"`
	URL   string `json:"url"`
	Site  string `json:"site"`
	Type  string `json:"type"`
	Notes string `json:"notes"`
}

// PageInfo describes pagination state.
type PageInfo struct {
	Total       int  `json:"total"`
	CurrentPage int  `json:"currentPage"`
	LastPage    int  `json:"lastPage"`
	HasNextPage bool `json:"hasNextPage"`
	PerPage     int  `json:"perPage"`
}

// Page wraps pagination data plus media results.
type Page struct {
	PageInfo PageInfo `json:"pageInfo"`
	Media    []Anime  `json:"media"`
}

// AnimeResponse is the response of a single media query.
type AnimeResponse struct {
	Media *Anime `json:"Media"`
}

// PageResponse is the response of a paged media query.
type PageResponse struct {
	Page *Page `json:"Page"`
}

// PageMeta keeps pagination plus a page of results.
type PageMeta struct {
	Anime []Anime
	Info  PageInfo
}

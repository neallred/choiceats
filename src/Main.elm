module Main exposing (main)

import Browser exposing (..)
import Browser.Navigation as Nav
import Data.AuthToken as AuthToken exposing (AuthToken(..))
import Data.Recipe exposing (Slug)
import Data.Session exposing (Session)
import Data.User as User exposing (Name(..), User, UserId(..))
import Html exposing (..)
import Json.Decode as Decode exposing (Decoder, Value)
import Json.Encode as Encode
import Menu
import Page.Errored as Errored exposing (PageLoadError, pageLoadError)
import Page.Login as Login
import Page.NotFound as NotFound
import Page.Randomizer as Randomizer
import Page.RecipeDetail as RecipeDetail
import Page.RecipeEditor as RecipeEditor
import Page.Recipes as Recipes
import Page.Signup as Signup
import Ports
import Route exposing (Route, routeToTitle)
import Task
import Url
import Verbiages exposing (errors, titles)
import Views.Page as Page exposing (ActivePage(..))


type Page
    = Blank
    | NotFound
    | Errored PageLoadError
    | Login Login.Model
    | Signup Signup.Model
    | Randomizer Randomizer.Model
    | RecipeDetail RecipeDetail.Model
    | Recipes Recipes.Model
    | RecipeEditor (Maybe Slug) RecipeEditor.Model


type PageState
    = Loaded Page
    | TransitioningFrom Page



-- MODEL --


type alias Model =
    { session : Session
    , pageState : PageState
    , apiUrl : String
    , navKey : Nav.Key
    , url : Url.Url
    }


type alias Flags =
    { apiUrl : String
    , session : User
    }


encodeToken : AuthToken -> Value
encodeToken (AuthToken token) =
    Encode.string token


decodeToken : Decoder AuthToken
decodeToken =
    Decode.string
        |> Decode.map AuthToken


decodeName : Decoder User.Name
decodeName =
    Decode.string
        |> Decode.map User.Name


decodeUserId : Decoder User.UserId
decodeUserId =
    Decode.string
        |> Decode.map User.UserId


flagsDecoder : String -> Result Decode.Error User
flagsDecoder =
    Decode.decodeString
        (Decode.field "session"
            (Decode.map4 User
                (Decode.field "email" Decode.string)
                (Decode.field "token" decodeToken)
                (Decode.field "name" decodeName)
                (Decode.field "userId" decodeUserId)
            )
        )


apiUrlDecoder :
    String
    -> Result Decode.Error String -- Success string is apiUrl
apiUrlDecoder =
    Decode.decodeString (Decode.field "api_url" Decode.string)


init : Value -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init val url navKey =
    let
        resultStringFlags =
            Decode.decodeValue Decode.string val

        stringifiedFlags =
            case resultStringFlags of
                Ok flags ->
                    flags

                Err _ ->
                    """{"bad": "deal dewd"}"""

        apiUrl =
            case apiUrlDecoder stringifiedFlags of
                Ok decodedApiUrl ->
                    decodedApiUrl

                _ ->
                    "http://localhost:4000"

        session =
            case flagsDecoder stringifiedFlags of
                Ok flags ->
                    { user = Just flags }

                _ ->
                    { user = Nothing }

        urlRoute =
            Route.fromUrl url

        effectiveRoute =
            if urlRoute == Nothing then
                if session.user == Nothing then
                    Just Route.Login

                else
                    Just Route.Root

            else
                urlRoute
    in
    setRoute effectiveRoute
        { pageState = Loaded initialPage
        , session = session
        , apiUrl = apiUrl
        , url = url
        , navKey = navKey
        }


initialPage : Page
initialPage =
    Blank



-- VIEW --


view : Model -> Browser.Document Msg
view model =
    case model.pageState of
        Loaded page ->
            viewPage model.session False page

        TransitioningFrom page ->
            viewPage model.session True page



-- TODO: Do all title setting in this function as data is available rather than on route changes


viewPage : Session -> Bool -> Page -> Browser.Document Msg
viewPage session isLoading page =
    let
        frame =
            Page.frame isLoading session.user
    in
    case page of
        NotFound ->
            frame Page.Other titles.notFound (NotFound.view session)

        Blank ->
            -- for initial page load, while loading data via HTTP
            frame Page.Other titles.loading (Html.text "")

        Errored subModel ->
            frame Page.Other titles.error (Errored.view session subModel)

        Login subModel ->
            frame Page.Login titles.signIn (Html.map LoginMsg (Login.view session subModel))

        Signup subModel ->
            frame Page.Signup titles.signUp (Html.map SignupMsg (Signup.view session subModel))

        Randomizer subModel ->
            frame Page.Randomizer titles.ideas (Html.map RandomizerMsg (Randomizer.view session subModel))

        Recipes subModel ->
            let
                mappedHtml =
                    Html.map RecipesMsg (Recipes.view session subModel)
            in
            frame Page.Recipes titles.recipes mappedHtml

        RecipeDetail subModel ->
            let
                mappedHtml =
                    Html.map RecipeDetailMsg (RecipeDetail.view session subModel)

                title =
                    RecipeDetail.getRecipeTitle subModel
            in
            frame Page.Other title mappedHtml

        RecipeEditor maybeSlug subModel ->
            let
                activePage =
                    if maybeSlug == Nothing then
                        Page.NewRecipe

                    else
                        Page.Other

                title =
                    if maybeSlug == Nothing then
                        titles.addRecipe

                    else
                        titles.editRecipe

                mappedHtml =
                    Html.map RecipeEditorMsg (RecipeEditor.view subModel)
            in
            frame activePage title mappedHtml


subscriptions : a -> Sub Msg
subscriptions model =
    Sub.batch
        [ Sub.map SetUser sessionChange
        , Sub.map RecipeEditorMsg (Sub.map RecipeEditor.SetAutocompleteState Menu.subscription)
        ]


sessionChange : Sub (Maybe User)
sessionChange =
    Ports.onSessionChange (Decode.decodeValue User.decoder >> Result.toMaybe)


getPage : PageState -> Page
getPage pageState =
    case pageState of
        Loaded page ->
            page

        TransitioningFrom page ->
            page



-- UPDATE --


type Msg
    = SetRoute (Maybe Route)
    | InterceptUrlRequest Browser.UrlRequest
    | SetUser (Maybe User)
    | LoginMsg Login.Msg
    | SignupMsg Signup.Msg
    | RandomizerMsg Randomizer.Msg
    | RecipesMsg Recipes.Msg
    | RecipeDetailMsg RecipeDetail.Msg
    | RecipeEditorMsg RecipeEditor.Msg
    | RecipeDetailLoaded (Result PageLoadError RecipeDetail.Model)
    | EditRecipeLoaded Slug (Result PageLoadError RecipeEditor.Model)
    | NewRecipeLoaded (Result PageLoadError RecipeEditor.Model)


setRoute : Maybe Route -> Model -> ( Model, Cmd Msg )
setRoute maybeRoute model =
    let
        transition toMsg task =
            ( { model | pageState = TransitioningFrom (getPage model.pageState) }
            , Task.attempt toMsg task
            )

        errored =
            pageErrored model
    in
    case maybeRoute of
        Nothing ->
            ( { model | pageState = Loaded NotFound }, Cmd.none )

        Just Route.NewRecipe ->
            case model.session.user of
                Just user ->
                    transition NewRecipeLoaded (RecipeEditor.initNew model.session model.apiUrl)

                Nothing ->
                    errored Page.NewRecipe errors.signInAdd

        Just (Route.EditRecipe slug) ->
            case model.session.user of
                Just user ->
                    transition (EditRecipeLoaded slug) (RecipeEditor.initEdit model.session slug model.apiUrl)

                Nothing ->
                    errored Page.Other errors.signInEdit

        Just Route.Root ->
            let
                rootRoute =
                    if model.session.user == Nothing then
                        Route.Login

                    else
                        Route.Recipes
            in
            ( model, Route.replaceUrl model.navKey rootRoute )

        Just Route.Login ->
            ( { model | pageState = Loaded (Login (Login.init model.apiUrl model.navKey)) }
            , Cmd.none
            )

        Just Route.Logout ->
            let
                session =
                    model.session
            in
            ( { model | session = { session | user = Nothing } }
            , Cmd.batch
                [ Ports.storeSession Nothing
                , Route.replaceUrl model.navKey Route.Login
                ]
            )

        Just Route.Signup ->
            ( { model | pageState = Loaded (Signup (Signup.initModel model.apiUrl model.navKey)) }
            , Cmd.none
            )

        Just Route.Randomizer ->
            let
                ( newModel, newMsg ) =
                    Randomizer.init model.session model.apiUrl
            in
            ( { model | pageState = Loaded (Randomizer newModel) }
            , Cmd.map RandomizerMsg newMsg
            )

        Just Route.Recipes ->
            let
                ( newModel, newMsg ) =
                    Recipes.init model.session model.apiUrl
            in
            ( { model | pageState = Loaded (Recipes newModel) }
            , Cmd.map RecipesMsg newMsg
            )

        Just (Route.RecipeDetail slug) ->
            let
                initRecipeDetail =
                    RecipeDetail.init model.session slug model.apiUrl
            in
            transition RecipeDetailLoaded initRecipeDetail


pageErrored : Model -> ActivePage -> String -> ( Model, Cmd msg )
pageErrored model activePage errorMessage =
    let
        error =
            Errored.pageLoadError activePage errorMessage
    in
    ( { model | pageState = Loaded (Errored error) }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    updatePage (getPage model.pageState) msg model


updatePage : Page -> Msg -> Model -> ( Model, Cmd Msg )
updatePage page msg model =
    let
        session =
            model.session

        toPage toModel toMsg subUpdate subMsg subModel =
            let
                ( newModel, newCmd ) =
                    subUpdate subMsg subModel
            in
            ( { model | pageState = Loaded (toModel newModel) }, Cmd.map toMsg newCmd )

        errored =
            pageErrored model
    in
    case ( msg, page ) of
        ( SetRoute route, _ ) ->
            setRoute route model

        ( InterceptUrlRequest urlRequest, _ ) ->
            case urlRequest of
                Internal url ->
                    case Route.fromUrl url of
                        Just route ->
                            case model.session.user of
                                Nothing ->
                                    if Route.needsAuth route then
                                        ( model, Nav.replaceUrl model.navKey (Route.routeToString Route.Login) )

                                    else
                                        ( model, Nav.pushUrl model.navKey (Url.toString url) )

                                -- So far, the only special auth route is edit recipe
                                -- but until the data is loaded it isn't known for sure
                                -- whether the user owns that recipe, so handle it in EditRecipeLoaded
                                Just user ->
                                    ( model, Nav.pushUrl model.navKey (Url.toString url) )

                        Nothing ->
                            ( model, Cmd.none )

                External externalLink ->
                    ( model, Nav.load externalLink )

        ( EditRecipeLoaded slug res, _ ) ->
            let
                thingLoaded =
                    case res of
                        Ok subModel ->
                            case model.session.user of
                                Nothing ->
                                    Errored (pageLoadError Page.Other errors.signInEdit)

                                Just user ->
                                    let
                                        userId =
                                            case user.userId of
                                                UserId id ->
                                                    id

                                        recipeOwnerId =
                                            subModel.editingRecipe.authorId
                                    in
                                    if userId == recipeOwnerId then
                                        RecipeEditor (Just slug) subModel

                                    else
                                        Errored (pageLoadError Page.Other errors.signInEdit)

                        Err error ->
                            Errored error
            in
            ( { model | pageState = Loaded thingLoaded }, Cmd.none )

        ( NewRecipeLoaded res, _ ) ->
            let
                thingLoaded =
                    case res of
                        Ok subModel ->
                            RecipeEditor Nothing subModel

                        Err error ->
                            Errored error
            in
            ( { model | pageState = Loaded thingLoaded }, Cmd.none )

        ( SetUser user, _ ) ->
            let
                cmd =
                    -- If just signed out, then redirect to Login
                    if session.user /= Nothing && user == Nothing then
                        Route.replaceUrl model.navKey Route.Login

                    else
                        Cmd.none
            in
            ( { model | session = { session | user = user } }, cmd )

        ( LoginMsg subMsg, Login subModel ) ->
            let
                ( ( pageModel, cmd ), msgFromPage ) =
                    Login.update subMsg subModel model.navKey

                newModel =
                    case msgFromPage of
                        Login.NoOp ->
                            model

                        Login.SetUser user ->
                            { model | session = { user = Just user } }
            in
            ( { newModel | pageState = Loaded (Login pageModel) }, Cmd.map LoginMsg cmd )

        ( SignupMsg subMsg, Signup subModel ) ->
            let
                ( ( pageModel, cmd ), msgFromPage ) =
                    Signup.update subMsg subModel

                newModel =
                    case msgFromPage of
                        Signup.NoOp ->
                            model

                        Signup.SetUser user ->
                            { model | session = { user = Just user } }
            in
            ( { newModel | pageState = Loaded (Signup pageModel) }, Cmd.map SignupMsg cmd )

        ( RandomizerMsg subMsg, Randomizer subModel ) ->
            let
                ( ( pageModel, cmd ), msgFromPage ) =
                    Randomizer.update subMsg subModel

                newModel =
                    case msgFromPage of
                        Randomizer.NoOp ->
                            model
            in
            ( { newModel | pageState = Loaded (Randomizer pageModel) }, Cmd.map RandomizerMsg cmd )

        ( RecipesMsg subMsg, Recipes subModel ) ->
            let
                ( ( pageModel, cmd ), msgFromPage ) =
                    Recipes.update subMsg subModel

                newModel =
                    case msgFromPage of
                        Recipes.NoOp ->
                            model
            in
            ( { newModel | pageState = Loaded (Recipes pageModel) }, Cmd.map RecipesMsg cmd )

        ( RecipeDetailMsg subMsg, RecipeDetail subModel ) ->
            case subMsg of
                RecipeDetail.ReceiveDeleteRecipe res ->
                    ( model, Route.replaceUrl model.navKey Route.Recipes )

                _ ->
                    let
                        ( ( pageModel, cmd ), msgFromPage ) =
                            RecipeDetail.update subMsg subModel

                        newModel =
                            case msgFromPage of
                                RecipeDetail.NoOp ->
                                    model
                    in
                    ( { newModel | pageState = Loaded (RecipeDetail pageModel) }, Cmd.map RecipeDetailMsg cmd )

        ( RecipeDetailLoaded result, _ ) ->
            let
                thingLoaded =
                    case result of
                        Ok subModel ->
                            RecipeDetail subModel

                        Err error ->
                            Errored error
            in
            ( { model | pageState = Loaded thingLoaded }, Cmd.none )

        ( RecipeEditorMsg subMsg, RecipeEditor slug subModel ) ->
            case model.session.user of
                Nothing ->
                    if slug == Nothing then
                        errored Page.NewRecipe
                            errors.signInAdd

                    else
                        errored Page.Other
                            errors.signInEdit

                Just _ ->
                    case subMsg of
                        RecipeEditor.RecipeSubmitted recipeSubmitResult ->
                            case recipeSubmitResult of
                                Ok recipe ->
                                    ( model, Route.replaceUrl model.navKey (Route.RecipeDetail (Data.Recipe.Slug recipe.id)) )

                                _ ->
                                    toPage (RecipeEditor slug) RecipeEditorMsg RecipeEditor.update subMsg subModel

                        _ ->
                            toPage (RecipeEditor slug) RecipeEditorMsg RecipeEditor.update subMsg subModel

        ( _, NotFound ) ->
            -- Disregard incoming messages when on the NotFound page.
            ( model, Cmd.none )

        ( _, _ ) ->
            ( model, Cmd.none )



-- MAIN --


onUrlChange : Url.Url -> Msg
onUrlChange url =
    SetRoute (Route.fromUrl url)


onUrlRequest : Browser.UrlRequest -> Msg
onUrlRequest route =
    InterceptUrlRequest route


main : Program Value Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , onUrlRequest = onUrlRequest
        , onUrlChange = onUrlChange
        , subscriptions = subscriptions
        }

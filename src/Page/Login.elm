module Page.Login exposing (ExternalMsg(..), Model, Msg, init, update, view)

{-| The login page.
-}

import Browser.Navigation as Nav
import Data.Session exposing (Session)
import Data.User exposing (User)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Decode exposing (Decoder, decodeString, field, string)
import Json.Decode.Pipeline exposing (optional)
import Request.User exposing (storeSession)
import Route exposing (Route)



-- MODEL --


words =
    { email = "Email"
    , password = "Password"
    , login = "Login"
    , signup = "Sign up"
    , failLogin = "Unable to log in."
    , blankEmail = "Email can't be blank."
    , blankPassword = "Password can't be blank."
    }


type alias Model =
    { errors : List Error
    , email : String
    , password : String
    , apiUrl : String
    , navKey : Nav.Key
    }


init : String -> Nav.Key -> Model
init apiUrl navKey =
    { errors = []
    , email = ""
    , password = ""
    , apiUrl = apiUrl
    , navKey = navKey
    }


view : Session -> Model -> Html Msg
view session model =
    div
        [ class "ui container" ]
        [ Html.form
            [ class "ui form"
            , style "max-width" "700px"
            , style "margin" "0 auto"
            , onSubmit SubmitForm
            ]
            [ h1 [ class "ui header", style "font-family" "fira-code" ] [ text words.login ]
            , viewInput model.email words.email "text" SetEmail
            , viewInput model.password words.password "password" SetPassword
            , br [] []
            , div []
                [ button
                    [ type_ "submit"
                    , class "ui primary button"
                    , disabled (not (hasLength model.email) || not (hasLength model.password))
                    ]
                    [ text words.login ]
                ]
            , br [] []
            , br [] []
            , a [ Route.href Route.Signup ]
                [ button
                    [ type_ "button"
                    , class "ui button"
                    ]
                    [ text words.signup ]
                ]
            ]
        ]


viewInput : String -> LabelName -> InputAttr -> (String -> Msg) -> Html Msg
viewInput userInput labelName inputAttr inputType =
    let
        idName =
            String.filter isIdChar labelName
    in
    div [ class "field" ]
        [ label [ for idName ] [ text labelName ]
        , div [ class "ui input" ]
            [ input
                [ type_ inputAttr
                , onInput inputType
                , value userInput
                , id idName
                ]
                []
            ]
        ]



-- UPDATE --


type Msg
    = SubmitForm
    | SetEmail String
    | SetPassword String
    | LoginCompleted (Result Http.Error User)


type ExternalMsg
    = NoOp
    | SetUser User


hasLength : String -> Bool
hasLength str =
    not <| String.isEmpty str


checkLoginInputs : Model -> List Error
checkLoginInputs model =
    let
        afterCheckEmail =
            if hasLength model.email then
                []

            else
                [ ( Email, words.blankEmail ) ]

        afterCheckPassword =
            if hasLength model.email then
                afterCheckEmail

            else
                ( Password, words.blankPassword ) :: afterCheckEmail
    in
    afterCheckPassword


update : Msg -> Model -> Nav.Key -> ( ( Model, Cmd Msg ), ExternalMsg )
update msg model navKey =
    case msg of
        SubmitForm ->
            case checkLoginInputs model of
                [] ->
                    ( ( { model | errors = [] }, Http.send LoginCompleted (Request.User.login model) )
                    , NoOp
                    )

                errors ->
                    ( ( { model | errors = errors }, Cmd.none ), NoOp )

        SetEmail email ->
            ( ( { model | email = email }, Cmd.none ), NoOp )

        SetPassword password ->
            ( ( { model | password = password }, Cmd.none ), NoOp )

        LoginCompleted (Err error) ->
            let
                errorMessages =
                    case error of
                        Http.BadStatus response ->
                            response.body
                                |> decodeString (field "errors" errorsDecoder)
                                |> Result.withDefault []

                        _ ->
                            [ words.failLogin ]
            in
            ( ( { model | errors = List.map (\err -> ( Form, err )) errorMessages }, Cmd.none )
            , NoOp
            )

        LoginCompleted (Ok user) ->
            ( ( model, Cmd.batch [ storeSession user, Route.replaceUrl model.navKey Route.Recipes ] )
            , SetUser user
            )



-- VALIDATION --


type Field
    = Form
    | Email
    | Password


{-| Recording validation errors on a per-field basis facilitates displaying them inline next to the field where the error occurred.

need a view function such as

viewFormErrors : Field -> List Error -> Html msg

filters the list of errors to render only the ones for the give Field

so you can call this:

viewFormErrors Email model.errors

next to the email field, and it only gets the pertinent errors :)

-}
type alias Error =
    ( Field, String )


errorsDecoder : Decoder (List String)
errorsDecoder =
    Decode.succeed (\emailOrPassword email username password -> List.concat [ emailOrPassword, email, username, password ])
        |> optionalError "email or password"
        |> optionalError "email"
        |> optionalError "username"
        |> optionalError "password"


optionalError : String -> Decoder (List String -> a) -> Decoder a
optionalError fieldName =
    let
        errorToString errorMessage =
            String.join " " [ fieldName, errorMessage ]
    in
    optional fieldName (Decode.list (Decode.map errorToString string)) []


isIdChar : Char -> Bool
isIdChar char =
    notDash char && notSpace char


notDash : Char -> Bool
notDash char =
    char /= '-'


notSpace : Char -> Bool
notSpace char =
    char /= ' '


type alias LabelName =
    String


type alias InputAttr =
    String

port module Signup exposing (main)

-- ELM-LANG MODULES
import Html exposing (Html, div, text, label, input, button, h1, form)
import Html.Attributes exposing (disabled, type_, class, style, value, for, id)
import Html.Events exposing (onWithOptions, onClick, onInput)
import Http exposing (Error, send, post, stringBody)
import Json.Decode as JD exposing (string, field, map4)
import Json.Encode as JE exposing (object, string, encode)
import Regex exposing (regex, caseInsensitive)

-- APP MODULES
import Signup.Types as T exposing (..)

main =
  Html.programWithFlags
  { update        = update
  , view          = viewSignup
  , init          = init
  , subscriptions = subscriptions
  }

init : T.Flags -> (T.Model, Cmd T.Msg)
init initFlags = 
  ({formFields =
      { email = emptyUserData
      , firstName = emptyUserData
      , lastName = emptyUserData
      , password = emptyUserData
      , passwordCheck = emptyUserData
      }
    , flags = initFlags
    , canSubmitForm = False
    , loggedIn = False
    , serverFeedback = ""
  }, Cmd.none )

emailRegex = caseInsensitive (regex "^\\S+@\\S+\\.\\S+$")
  
validateEmail : String -> Bool
validateEmail email =
    Regex.contains emailRegex email

setEmail : String -> T.SignupFields -> T.SignupFields
setEmail emailInput fields =
  let
    hasInput = hasLength emailInput
    isValidEmail = validateEmail emailInput

    message =

      if not hasInput

        then "Enter an email address."

      else if not isValidEmail

        then "Enter a valid email address."

      else ""

  in
    { fields | email =
      { userInput = emailInput
      , message = message
      , isValid = hasInput && isValidEmail
      }
    }

setFirstName : String -> T.SignupFields -> T.SignupFields
setFirstName firstNameInput fields =
  let
    hasInput = hasLength firstNameInput

  in
    { fields | firstName =
      { userInput = firstNameInput
      , message = if hasInput then "" else "Enter a first name."
      , isValid = hasInput
      }
    }

setLastName : String -> T.SignupFields -> T.SignupFields
setLastName lastNameInput fields =
  let
    hasInput = hasLength lastNameInput

  in
    { fields | lastName =
      { userInput = lastNameInput
      , message = if hasInput then "" else "Enter a last name."
      , isValid = hasInput
      }
    }

createWordRegex word = caseInsensitive (regex ("^.*" ++ word ++ ".*$"))

passwordRegex = createWordRegex "password"
  
setPassword : String -> T.SignupFields -> T.SignupFields
setPassword passwordInput fields =
  let
    hasInput = hasLength passwordInput

    passwordIsPassword = Regex.contains passwordRegex passwordInput

    passwordIsName =
      (
        ( String.length fields.firstName.userInput > 0
        && Regex.contains (createWordRegex fields.firstName.userInput) passwordInput
        )
        ||
        ( String.length fields.lastName.userInput > 0
        && Regex.contains (createWordRegex fields.lastName.userInput) passwordInput
        )
      )

    minimum_password_length = 6

    passwordIsLongEnough = String.length passwordInput >= minimum_password_length

    passwordsMatch = fields.passwordCheck.userInput == passwordInput

    passwordCheckHasInput = hasLength fields.passwordCheck.userInput

    bothPasswordsHaveInput = hasInput && passwordCheckHasInput 


    message =
      if False
        then "Enter a password."

      else if passwordIsPassword
        then "You can do better than \"password\" for a password."

      else if passwordIsName
        then "You can do better than using your name for a password."

      else if hasInput && not passwordIsLongEnough
        then "Password must be at least " ++ (toString minimum_password_length) ++ " characters long."

      else if bothPasswordsHaveInput && not passwordsMatch
        then "Passwords must match."

      else ""

  in
    {fields | password = { userInput = passwordInput
    , message = message
    , isValid =
      ( hasInput
      && (not passwordIsPassword)
      && passwordIsLongEnough
      && not passwordIsName
      && passwordsMatch
      )
    }}


setPasswordCheck : String -> T.SignupFields -> T.SignupFields
setPasswordCheck passwordCheckInput fields =
  -- Keep the password checking logic in the setPassword method
  { fields | passwordCheck =
    { userInput = passwordCheckInput
    , message = ""
    , isValid = True
    }
  }

hasLength : String -> Bool
hasLength str =
  not <| String.isEmpty str

getCanSubmitForm : T.SignupFields -> Bool
getCanSubmitForm f =
     (f.email.isValid         && hasLength f.email.userInput        )
  && (f.firstName.isValid     && hasLength f.firstName.userInput    )
  && (f.lastName.isValid      && hasLength f.lastName.userInput     )
  && (f.password.isValid      && hasLength f.password.userInput     )
  && (f.passwordCheck.isValid && hasLength f.passwordCheck.userInput)
 
update : T.Msg -> T.Model -> (T.Model, Cmd T.Msg)
update msg model = 
  case msg of

    T.Email str ->
      let
        newFields = setEmail str model.formFields

      in
        ({ model | formFields = newFields
        , canSubmitForm = getCanSubmitForm newFields
        }, Cmd.none)

    T.FirstName str ->
      let
        newFields = setFirstName str model.formFields
          |> (setPassword model.formFields.password.userInput)
          |> (setPasswordCheck model.formFields.passwordCheck.userInput)

      in
        ({model | formFields = newFields
        , canSubmitForm = getCanSubmitForm newFields
        }, Cmd.none)

    T.LastName str ->
      let
        newFields = setLastName str model.formFields
          |> (setPassword model.formFields.password.userInput)
          |> (setPasswordCheck model.formFields.passwordCheck.userInput)

      in
        ({model | formFields = newFields
        , canSubmitForm = getCanSubmitForm newFields
        }, Cmd.none)

    T.Password str ->
      let
        newFields = setPassword str model.formFields
          |> (setPasswordCheck model.formFields.passwordCheck.userInput)

      in
        ({model | formFields = newFields
        , canSubmitForm = getCanSubmitForm newFields
        }, Cmd.none)

    T.PasswordCheck str ->
      let
        newFields = setPasswordCheck str model.formFields
          |> (setPassword model.formFields.password.userInput)

      in
        ({model | formFields = newFields
        , canSubmitForm = getCanSubmitForm newFields
        }, Cmd.none)

    T.RequestAccount ->
      (model, requestAccount model)

    T.ReceiveResponse (Ok user)->
      ({model | loggedIn = True }, recordSignup <| stringifySession user)

    T.ReceiveResponse (Err err)->
      ({model | serverFeedback = toString err}, Cmd.none)

stringifySession : Session -> String
stringifySession session = 
  """ { "userId": """ ++ (toString session.userId) ++ """
  , "email": \"""" ++ session.email ++ """\" 
  , "name": \"""" ++ session.name ++ """\" 
  , "token": \"""" ++ session.token ++ """\" }"""
-- TODO: Find a better way to stringify this object

--  toString <| JE.object
--  [ ("userId", JE.string (toString session.userId))
--  , ("email", JE.string session.email)
--  , ("name", JE.string session.name)
--  , ("token", JE.string session.token)
--  ]

requestAccount : T.Model -> Cmd T.Msg
requestAccount model =
  let body =
  [ ("email", JE.string model.formFields.email.userInput)
  , ("firstName", JE.string model.formFields.firstName.userInput)
  , ("lastName", JE.string model.formFields.lastName.userInput)
  , ("password", JE.string model.formFields.password.userInput)
  ]

  in
  Http.send ReceiveResponse (
    Http.post
      "http://localhost:4000/user"
      (Http.stringBody
        "application/json; charset=utf-8"
        <| JE.encode 0
        <| JE.object body
      )
      <| sessionDecoder
  )

sessionDecoder : JD.Decoder Session
sessionDecoder =
  map4 Session
    (field "userId" JD.string)
    (field "email" JD.string)
    (field "name" JD.string)
    (field "token" JD.string)

port recordSignup : String -> Cmd msg

subscriptions : T.Model -> Sub T.Msg
subscriptions model =
  Sub.none

viewSignup : T.Model -> Html T.Msg
viewSignup model =
  let
    f = model.formFields

  in
    div [style [("max-width", "500px"), ("margin", "auto")]]
    [ 
      form [class "ui form"]
      [ h1
        [ style [("font-family", "Fira Code") , ("font-size", "25px")] ]
        [text "Signup!"]
      , viewInput f.email         "Email"       "text"     Email
      , viewInput f.firstName     "First Name"  "text"     FirstName
      , viewInput f.lastName      "Last Name"   "text"     LastName
      , viewInput f.password      "Password"    "password" Password
      , viewInput f.passwordCheck "Re-Password" "password" PasswordCheck
      , button
        [ type_ "submit"
        , class "ui primary button"
        , disabled <| not model.canSubmitForm
        , onWithOptions
            "click"
            { stopPropagation = True
            , preventDefault = True
            }
            (JD.succeed RequestAccount)
        ]
        [text "Signup"]
      , div [] [text <| toString model]
      ]
    ]

notDash : Char -> Bool
notDash char = char /= '-'

notSpace : Char -> Bool
notSpace char = char /= ' '

isIdChar : Char -> Bool
isIdChar char = notDash char && notSpace char

viewInput : T.FormField -> LabelName -> InputAttr -> (String -> T.Msg) -> Html T.Msg
viewInput formField labelName inputAttr inputType = 
  let
    idName = (String.filter isIdChar labelName)

  in
    div [class "field"]
    [ label [for idName] [text labelName]
    , div [class "ui input"]
      [
        input [ type_ inputAttr
              , onInput inputType
              , value formField.userInput
              , id idName
              ]
        []
      ]
    , viewError formField
    ]

viewError : T.FormField -> Html T.Msg
viewError field =
  div [class <| "ui error message " ++ (if hasLength field.message && (not field.isValid) then "visible" else "hidden")]
    [ div [class "header"] [text field.message] ]

-- can add ui [class "list"] [li[] [text var]] or p [] [text var] if need secondary error parts

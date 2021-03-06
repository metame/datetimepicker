module DateTimePicker.AnalogClock exposing (clock)

import Html exposing (Html, div)
import Svg exposing (Svg, svg, circle, line, g, text, text_)
import Svg.Attributes exposing (textAnchor, width, height, viewBox, cx, cy, r, fill, stroke, strokeWidth, x1, y1, x2, y2, x, y)
import DateTimePicker.SharedStyles exposing (datepickerNamespace, CssClasses(..))
import DateTimePicker.Internal exposing (InternalState(..), StateValue, getStateValue)
import DateTimePicker.Config exposing (Type(..))
import DateTimePicker.Events exposing (onMouseDownPreventDefault, onMouseMoveWithPosition, onPointerMoveWithPosition, onTouchMovePreventDefault, onPointerUp, MoveData)
import Date exposing (Date)
import Json.Decode
import DateTimePicker.Geometry exposing (Point)
import Dict
import String
import DateTimePicker.Helpers exposing (updateCurrentDate, updateTimeIndicator)
import DateTimePicker.ClockUtils exposing (hours, minutes, minutesPerFive)


{ id, class, classList } =
    datepickerNamespace


hourArrowLength : Int
hourArrowLength =
    50


minuteArrowLength : Int
minuteArrowLength =
    70


clock : Type msg -> (InternalState -> Maybe Date -> msg) -> InternalState -> Maybe Date -> Html msg
clock pickerType onChange state date =
    let
        stateValue =
            getStateValue state
    in
        div
            [ class [ AnalogClock ]
            ]
            [ svg
                [ width "200"
                , height "200"
                , viewBox "0 0 200 200"
                ]
                [ circle
                    [ cx "100"
                    , cy "100"
                    , r "100"
                    , fill "#eee"
                    , onMouseDownPreventDefault (mouseDownHandler pickerType state date onChange)
                    , onPointerUp (mouseDownHandler pickerType state date onChange)
                    , onMouseMoveWithPosition (mouseOverHandler state date onChange)
                    , onTouchMovePreventDefault (onChange state date)
                    , onPointerMoveWithPosition (mouseOverHandler state date onChange)
                    ]
                    []
                , case stateValue.activeTimeIndicator of
                    Just (DateTimePicker.Internal.MinuteIndicator) ->
                        g [] (minutesPerFive |> Dict.toList |> List.map (clockFace pickerType onChange state date))

                    _ ->
                        g [] (hours |> Dict.toList |> List.map (clockFace pickerType onChange state date))
                , arrow pickerType onChange state date
                , currentTime pickerType onChange state date
                ]
            ]


currentTime : Type msg -> (InternalState -> Maybe Date -> msg) -> InternalState -> Maybe Date -> Svg msg
currentTime pickerType onChange state date =
    let
        stateValue =
            getStateValue state

        time =
            stateValue.time

        hourArrowLength =
            50

        drawHour hour minute =
            Dict.get (toString hour) hours
                |> Maybe.map (flip (-) (toFloat minute * pi / 360))
                |> Maybe.map (DateTimePicker.Geometry.calculateArrowPoint originPoint hourArrowLength >> (drawArrow pickerType onChange state date))
                |> Maybe.withDefault (text "")

        drawMinute minute =
            Dict.get (toString minute) minutes
                |> Maybe.map (DateTimePicker.Geometry.calculateArrowPoint originPoint minuteArrowLength >> (drawArrow pickerType onChange state date))
                |> Maybe.withDefault (text "")
    in
        case ( stateValue.activeTimeIndicator, time.hour, time.minute, time.amPm ) of
            ( Nothing, Just hour, Just minute, Just _ ) ->
                g [] [ drawHour hour minute, drawMinute minute ]

            _ ->
                text ""


clockFace : Type msg -> (InternalState -> Maybe Date -> msg) -> InternalState -> Maybe Date -> ( String, Float ) -> Svg msg
clockFace pickerType onChange state date ( number, radians ) =
    let
        point =
            DateTimePicker.Geometry.calculateArrowPoint originPoint 85 radians
    in
        text_
            [ x <| toString point.x
            , y <| toString point.y
            , textAnchor "middle"
            , Svg.Attributes.dominantBaseline "central"
            , onMouseDownPreventDefault (mouseDownHandler pickerType state date onChange)
            , onPointerUp (mouseDownHandler pickerType state date onChange)
            ]
            [ text number ]


originPoint : Point
originPoint =
    Point 100 100


axisPoint : Point
axisPoint =
    Point 200 100


arrow : Type msg -> (InternalState -> Maybe Date -> msg) -> InternalState -> Maybe Date -> Svg msg
arrow pickerType onChange state date =
    let
        stateValue =
            getStateValue state

        length =
            case stateValue.activeTimeIndicator of
                Just (DateTimePicker.Internal.HourIndicator) ->
                    hourArrowLength

                Just (DateTimePicker.Internal.MinuteIndicator) ->
                    minuteArrowLength

                _ ->
                    0

        arrowPoint angle =
            angle
                |> DateTimePicker.Geometry.calculateArrowPoint originPoint length

        isJust maybe =
            case maybe of
                Just _ ->
                    True

                Nothing ->
                    False

        shouldDrawArrow =
            case stateValue.activeTimeIndicator of
                Just (DateTimePicker.Internal.HourIndicator) ->
                    isJust stateValue.time.hour

                Just (DateTimePicker.Internal.MinuteIndicator) ->
                    isJust stateValue.time.minute

                _ ->
                    False
    in
        case stateValue.currentAngle of
            Nothing ->
                text ""

            Just angle ->
                if shouldDrawArrow then
                    angle
                        |> arrowPoint
                        |> (drawArrow pickerType onChange state date)
                else
                    text ""


drawArrow : Type msg -> (InternalState -> Maybe Date -> msg) -> InternalState -> Maybe Date -> Point -> Svg msg
drawArrow pickerType onChange state date point =
    line
        [ x1 "100"
        , y1 "100"
        , x2 <| toString point.x
        , y2 <| toString point.y
        , strokeWidth "2px"
        , stroke "#aaa"
        , onMouseDownPreventDefault (mouseDownHandler pickerType state date onChange)
        , onPointerUp (mouseDownHandler pickerType state date onChange)
        ]
        []


mouseDownHandler : Type msg -> InternalState -> Maybe Date -> (InternalState -> Maybe Date -> msg) -> msg
mouseDownHandler pickerType state date onChange =
    let
        stateValue =
            getStateValue state

        updatedDate =
            updateCurrentDate pickerType stateValue

        updatedStateValue =
            case ( updatedDate, stateValue.activeTimeIndicator ) of
                ( Just _, _ ) ->
                    { stateValue | event = "analog.mouseDownHandler", activeTimeIndicator = Nothing, currentAngle = Nothing }

                ( _, Just (DateTimePicker.Internal.HourIndicator) ) ->
                    { stateValue | event = "analog.mouseDownHandler", activeTimeIndicator = Just DateTimePicker.Internal.MinuteIndicator, currentAngle = Nothing }

                ( _, Just (DateTimePicker.Internal.MinuteIndicator) ) ->
                    { stateValue | event = "analog.mouseDownHandler", activeTimeIndicator = Just DateTimePicker.Internal.AMPMIndicator, currentAngle = Nothing }

                _ ->
                    { stateValue | event = "analog.mouseDownHandler", activeTimeIndicator = Just DateTimePicker.Internal.HourIndicator, currentAngle = Nothing }
    in
        onChange
            (InternalState <| updateTimeIndicator stateValue)
            updatedDate


mouseOverHandler : InternalState -> Maybe Date -> (InternalState -> Maybe Date -> msg) -> MoveData -> Json.Decode.Decoder msg
mouseOverHandler state date onChange moveData =
    let
        stateValue =
            getStateValue state

        decoder updatedState =
            Json.Decode.succeed (onChange updatedState date)
    in
        case stateValue.activeTimeIndicator of
            Just (DateTimePicker.Internal.HourIndicator) ->
                decoder (updateHourState stateValue date moveData)

            Just (DateTimePicker.Internal.MinuteIndicator) ->
                decoder (updateMinuteState stateValue date moveData)

            _ ->
                decoder (InternalState stateValue)


updateHourState : StateValue -> Maybe Date -> MoveData -> InternalState
updateHourState stateValue date moveData =
    let
        currentAngle =
            DateTimePicker.Geometry.calculateAngle originPoint axisPoint (Point moveData.offsetX moveData.offsetY)

        closestHour =
            hours
                |> Dict.toList
                |> List.map (\( hour, radians ) -> ( ( hour, radians ), abs (radians - currentAngle) ))
                |> List.sortBy Tuple.second
                |> List.head
                |> Maybe.map (Tuple.first)

        updateTime time hour =
            { time | hour = hour |> Maybe.andThen (String.toInt >> Result.toMaybe) }
    in
        InternalState
            { stateValue
                | currentAngle =
                    Maybe.map Tuple.second closestHour
                , time = updateTime stateValue.time (Maybe.map Tuple.first closestHour)
            }


updateMinuteState : StateValue -> Maybe Date -> MoveData -> InternalState
updateMinuteState stateValue date moveData =
    let
        currentAngle =
            DateTimePicker.Geometry.calculateAngle originPoint axisPoint (Point moveData.offsetX moveData.offsetY)

        closestMinute =
            minutes
                |> Dict.toList
                |> List.map (\( minute, radians ) -> ( ( minute, radians ), abs (radians - currentAngle) ))
                |> List.sortBy Tuple.second
                |> List.head
                |> Maybe.map (Tuple.first)

        updateTime time minute =
            { time | minute = minute |> Maybe.andThen (String.toInt >> Result.toMaybe) }
    in
        InternalState
            { stateValue
                | currentAngle =
                    Maybe.map Tuple.second closestMinute
                , time = updateTime stateValue.time (Maybe.map Tuple.first closestMinute)
            }

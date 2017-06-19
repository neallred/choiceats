// @flow
import React from 'react'
import styled from 'styled-components'
import {
  Card,
  CardTitle,
  CardText,
  CardActions
} from 'material-ui/Card'

import FlatButton from 'material-ui/FlatButton'
import * as colors from '../../styles/colors'
import Ingredients from './components/ingredient-list'

import type { Recipe } from '../../types'

type RecipeProps = {
  recipe: Recipe;
  isLoggedIn: boolean;
  allowEdits: boolean;
}

export default ({
  recipe,
  isLoggedIn,
  allowEdits
}: RecipeProps) => {
  return (
    <Card style={{marginBottom: 25, maxWidth: 550}}>
      <CardTitle title={recipe.name} subtitle={recipe.author} />
      <CardText>
        <Ingredients ingredients={recipe.ingredients} />
        <Instructions>{ recipe.instructions }</Instructions>
      </CardText>
      {allowEdits && isLoggedIn && <CardActions style={{textAlign: 'right'}}>
        <FlatButton label='Edit'
          primary
          onClick={() => console.log('not yet connected to editRecipe mutation')} />
        <FlatButton label='Delete'
          secondary
          onClick={() => console.log('not yet connected to deleteRecipe mutation')} />
      </CardActions>}

    </Card>
  )
}

const Instructions = styled.div`
  margin-top: 15px;
  white-space: pre-wrap;
`

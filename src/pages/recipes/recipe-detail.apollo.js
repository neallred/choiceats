// @flow
import React from 'react'
import { compose, gql, graphql } from 'react-apollo'
import RecipeDetail from './recipe-detail'
import {connect} from 'react-redux'

import type { Recipe } from 'types'

type ApolloRecipeProps = {
  data: {
    loading: boolean,
    recipe: Recipe
  },
  selectedRecipeId: string,
  recipeIdToDelete: string,
  dispatch?: (action: {type: string}) => any,
  likeRecipe?: (arg: {}) => any,
  deleteRecipe?: (arg: {variables: {recipeId: null | string | number}}) => any,
}

export const RecipeDetailApollo:(ApolloRecipeProps) => React.Element<any> =
({
  data,
  selectedRecipeId,
  recipeIdToDelete,
  dispatch = () => {},
  likeRecipe = () => {},
  deleteRecipe = () => {}
}) => {
  if (data.loading) {
    return <div> LOADING...</div>
  }

  const recipe = data.recipe || {}
  return <RecipeDetail recipe={recipe}
    selectedRecipeId={selectedRecipeId}
    recipeIdToDelete={recipeIdToDelete}
    likeRecipe={likeRecipe}
    deleteRecipe={deleteRecipe}
    dispatch={dispatch}
    />
}

const recipeQuery = gql`
  query RecipeById($recipeId: Int!) {
    recipe (recipeId: $recipeId) {
      id
      author
      authorId
      description
      imageUrl
      name
      instructions
      ingredients {
        name
        unit {
          name
          abbr
        }
        quantity
      }
      likes
    }
  }
`

const deleteRecipe = gql`
  mutation deleteRecipe($recipeId: ID!) {
    deleteRecipe(recipeId: $recipeId) {
      recipeId
      deleted
    }
  }
`

const likeRecipe = gql`
  mutation likeRecipe($userId: ID!, $recipeId: ID!) {
    likeRecipe(userId: $userId, recipeId: $recipeId) {
      id
      likes
      youLike
    }
  }
`

type RouteMatch = {
  match: { params: { recipeId: string } };
}
type RecipeQueryOptions = (RouteMatch) => any;
const options: RecipeQueryOptions = ({match}) => ({
  variables: {
    recipeId: match.params.recipeId
  }
})

const mapStateToProps = state => ({
  selectedRecipeId: state.ui.selectedRecipeId,
  recipeIdToDelete: state.ui.recipeIdToDelete
})

export default connect(mapStateToProps)(compose(
  graphql(likeRecipe, {name: 'likeRecipe'}),
  graphql(deleteRecipe, {name: 'deleteRecipe'}),
  graphql(recipeQuery, { options })
)(RecipeDetailApollo))

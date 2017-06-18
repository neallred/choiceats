// @flow
import React, { Component } from 'react'
import { connect } from 'react-redux'
import { withRouter } from 'react-router-dom'
import FlatButton from 'material-ui/FlatButton'

import { logout } from '../../state/action-creators'

import type { ContextRouter } from 'react-router-dom'
import type { ConnectedProps } from 'types'

export class LogoutButton extends Component {
  props: ConnectedProps & ContextRouter
  onClick: () => void

  constructor (props: ConnectedProps & ContextRouter) {
    super(props)
    this.onClick = this._onClick.bind(this)
  }

  render () {
    return (
      <FlatButton
        onClick={this.onClick}
        label='Logout' />
    )
  }

  _onClick () {
    const { history, dispatch } = this.props
    dispatch(logout())
    history.push('/login')
  }
}

export default withRouter(connect()(LogoutButton))

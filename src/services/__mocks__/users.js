/* eslint-env jest */
// @flow

export const promises = {
  login: []
}

export const login = jest.fn(() => {
  const p = Promise.resolve()
  promises.login.push(p)
  return p
})
'use strict';

const webpack = require('webpack');
const path = require('path');
const ExtractTextPlugin = require("extract-text-webpack-plugin");

const scssdir = '_scss';
const webroot = '.';
const assetdir = webroot + '/assets';

const extractSass = new ExtractTextPlugin({filename: 'bundle.min.css'});

module.exports = {
    entry: ['./_js/index.js', './_scss/bundle.scss'],
    devtool: 'source-map',
    module: {
        rules: [
            {
                test: /.scss$/,
                use: extractSass.extract({
                     use: [
                         {
                            loader: 'css-loader' ,
                            options: {
                                sourceMap: true,
                                importLoaders: 1
                            }
                         }, 
                         { 
                             loader: 'postcss-loader',
                             options: {
                                 sourceMap: true
                             }
                         },
                         { 
                            loader: 'sass-loader',
                            options: {
                                sourceMap: true
                            }
                         }
                     ],
                     fallback: 'style-loader',
                }),
            },
            {
                test: /.(ttf|otf|eot|svg|woff(2)?)(\?[a-z0-9]+)?$/,
                use: [{
                    loader: 'file-loader',
                    options: {
                        name: '[name].[ext]',
                        outputPath: 'fonts/'
                    }
                }]
            }
        ]
    },
    plugins: [
        extractSass,
        new webpack.ProvidePlugin({
            $: 'jquery',
            jQuery: 'jquery',
            'window.jQuery': 'jquery',
            Popper: ['popper.js', 'default'],
            Tether: 'tether'
        })
    ],
    output: {
        filename: 'bundle.min.js',
        path: path.resolve(__dirname, assetdir)
    }
};

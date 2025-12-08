/**
 * Comment Model
 * Mongoose schema for post comments
 * Reference: /design/DatabaseDesign.md
 */

import mongoose, { Document, Schema, Types } from 'mongoose';

export interface IComment extends Document {
  post: Types.ObjectId;
  author: Types.ObjectId;
  content: string;
  parentComment?: Types.ObjectId;
  isEdited: boolean;
  isDeleted: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const commentSchema = new Schema<IComment>(
  {
    post: {
      type: Schema.Types.ObjectId,
      ref: 'Post',
      required: true,
      index: true,
    },
    author: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    content: {
      type: String,
      required: true,
      maxlength: 2000,
    },
    parentComment: {
      type: Schema.Types.ObjectId,
      ref: 'Comment',
      default: null,
    },
    isEdited: {
      type: Boolean,
      default: false,
    },
    isDeleted: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
    collection: 'comments',
  }
);

// Compound index for listing comments on a post
commentSchema.index({ post: 1, isDeleted: 1, createdAt: 1 });

// Index for threaded comments
commentSchema.index({ parentComment: 1, createdAt: 1 });

export const Comment = mongoose.model<IComment>('Comment', commentSchema);

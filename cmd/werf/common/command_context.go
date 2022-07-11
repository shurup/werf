package common

import (
	"context"

	"github.com/spf13/cobra"
)

const (
	cmdDataContextKey = "cmdData"
)

func NewContextWithCmdData(ctx context.Context, cmdData *CmdData) context.Context {
	return context.WithValue(ctx, cmdDataContextKey, cmdData)
}

func GetCmdDataFromContext(ctx context.Context) *CmdData {
	return ctx.Value(cmdDataContextKey).(*CmdData)
}

func SetCommandContext(ctx context.Context, cmd *cobra.Command) *cobra.Command {
	cmd.SetContext(ctx)
	return cmd
}

import Toybox.Lang;

module LabelPickerBuilder {

    function build(haState as HaState) as Array<LabelPickerRowModel> {
        var labels = haState.getLabels();
        var included = haState.getIncludedLabels();
        var ids = labels.keys();
        var rows = [] as Array<LabelPickerRowModel>;

        for (var index = 0; index < ids.size(); index++) {
            var id = ids[index] as String;
            rows.add(new LabelPickerRowModel(id, labels.get(id) as String, included.hasKey(id)));
        }

        rows.sort(new LabelComparator());

        return rows;
    }
}

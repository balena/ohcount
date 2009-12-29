import os
import ohcount

def _LocList2Dict(loc):
    return {
        'lang': loc.language,
        'code': loc.code,
        'comments': loc.comments,
        'blanks': loc.blanks,
        'filecount': loc.filecount
    }

class SourceFile(object):

    def __init__(self, base):
        self.base = base

    def __getattr__(self, name):
        if (name == 'filepath'):
            return self.base.filepath
        if (name == 'filename'):
            return self.base.filename
        if (name == 'ext'):
            return self.base.ext
        if (name == 'contents'):
            return self.base.get_contents()
        if (name == 'size'):
            return self.base.contents_size()
        if (name == 'language'):
            return self.base.get_language()
        if (name == 'licenses'):
            return self.base.get_license_list()
        if (name == 'locs'):
            return self.base.get_loc_list()
        object.__getattr__(self, name)

    def __setattr__(self, name, value):
        if (name == 'contents'):
            return self.base.set_contents(value)
        object.__setattr__(self, name, value)

    def __str__(self):
        return {
            'filepath': self.filepath,
            'filename': self.filename,
            'ext': self.ext,
            'size': self.size,
            'language': self.language,
        }.__str__()

class SourceFileList(object):

    def __init__(self, **kwargs):
        self.base = ohcount.SourceFileList(kwargs)

    def __iter__(self):
        return self.next()

    def next(self):
        iter = self.base.head
        while iter is not None:
            yield SourceFile(iter.sf)
            iter = iter.next

    def analyze_languages(self):
        result = []
        list = self.base.analyze_languages()
        if list is not None:
            iter = list.head
            while iter is not None:
                result.append(_LocList2Dict(iter.loc))
                iter = iter.next
        return result

    def add_directory(self, path):
        if not os.path.isdir(xraydir):
            raise SyntaxError('Input path is not a directory: %s' % path)
        self.base.add_directory(path)

    def add_file(self, filepath):
        if not os.path.isfile(xraydir):
            raise SyntaxError('Input path is not a file: %s' % filepath)
        self.base.add_file(filepath)

